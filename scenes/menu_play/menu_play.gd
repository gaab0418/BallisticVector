extends Control
## Menu principal. O tanque do fundo mira e dispara de tempos em tempos,
## desenhando uma parabola no ceu. Navegavel por teclado (setas + Enter).

const BACKGROUND_PLANE = preload("res://assets/sprites/airplane_enemy_01.png")
const HULL_TEX = preload("res://assets/sprites/tank_hull.png")
const BARREL_TEX = preload("res://assets/sprites/tank_barrel.png")
const UiModalScript = preload("res://scripts/ui/ui_modal.gd")
const AudioSettingsScript = preload("res://scripts/ui/audio_settings.gd")
const MenuShotScript = preload("res://scenes/menu_play/menu_shot.gd")

const MUSIC_BG := "res://assets/audio/musica_fundo.wav"
const SFX_FIRE := "res://assets/audio/cannon_fire.ogg"
const WAR_MAP_SCENE := "res://scenes/war_map/war_map.tscn"

## O tanque olha para a esquerda (espelhado), atirando por cima do acampamento.
const TANK_POS := Vector2(1010, 560)
const TANK_SCALE := 0.8
## Munhao do cano no sprite original (676x369), o mesmo usado na arena.
const PIVOT_IMG := Vector2(404, 139)
const IMG_CENTER := Vector2(338, 184.5)
const GROUND_Y := 640.0

@onready var background: TextureRect = $Background

var spawn_timer: float = 0.0
var audio_modal: CanvasLayer
var credits_modal: CanvasLayer
var reset_modal: CanvasLayer
var _rig: Node2D
var _barrel_pivot: Node2D
var _shot: Node2D
var _fire_timer := 2.5
var _aim_target := -0.6
var _buttons: Array = []
var _teacher_btn: Button


func _ready() -> void:
	_setup_background()
	_build_tank()
	AudioManager.play_bgm(MUSIC_BG)
	_setup_ui()
	randomize()


func _setup_background() -> void:
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Cover, e nao scale: fora de 16:9 a foto seria esticada.
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_tank() -> void:
	_rig = Node2D.new()
	_rig.position = TANK_POS
	_rig.scale = Vector2(-TANK_SCALE, TANK_SCALE)
	add_child(_rig)

	_barrel_pivot = Node2D.new()
	_barrel_pivot.position = PIVOT_IMG - IMG_CENTER
	_rig.add_child(_barrel_pivot)
	var barrel := Sprite2D.new()
	barrel.texture = BARREL_TEX
	barrel.centered = false
	barrel.offset = Vector2(10, -21)
	_barrel_pivot.add_child(barrel)

	var hull := Sprite2D.new()
	hull.texture = HULL_TEX
	_rig.add_child(hull)

	_shot = MenuShotScript.new()
	_shot.visible = false
	add_child(_shot)
	_shot.finished.connect(func(): _fire_timer = randf_range(3.0, 5.5))


func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_background_plane()
		spawn_timer = randf_range(5.0, 10.0)

	# Cano procura o angulo devagar, como quem mira; depois dispara.
	_barrel_pivot.rotation = lerp_angle(_barrel_pivot.rotation, _aim_target, delta * 2.0)
	if _fire_timer > 0.0:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire()


func _fire() -> void:
	var angle := -rad_to_deg(_barrel_pivot.rotation)
	var muzzle := _barrel_pivot.to_global(Vector2(240, 0))
	_shot.fire(muzzle, angle, GROUND_Y, -1.0)
	AudioManager.play_sfx(SFX_FIRE)
	ArenaFx.spawn(self, muzzle, ArenaFx.Kind.MUZZLE, Vector2.LEFT.rotated(deg_to_rad(angle)))
	var kick := create_tween()
	kick.tween_property(_rig, "position:x", TANK_POS.x + 6.0, 0.05)
	kick.tween_property(_rig, "position:x", TANK_POS.x, 0.3)
	# Proximo tiro com outro angulo: cada parabola diferente da anterior.
	_aim_target = -deg_to_rad(randf_range(28.0, 62.0))
	_fire_timer = -1.0


func _spawn_background_plane() -> void:
	var plane = Sprite2D.new()
	plane.texture = BACKGROUND_PLANE
	plane.scale = Vector2(0.015, 0.015)
	plane.modulate = UiTokens.MENU_PLANE_TINT
	plane.position = Vector2(-100, randf_range(80, 220))
	add_child(plane)
	move_child(plane, 1)

	var tween = create_tween()
	var travel_time = randf_range(15.0, 25.0)
	tween.tween_property(plane, "position:x", 1400.0, travel_time)
	tween.tween_callback(plane.queue_free)


func _setup_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	# Coluna ancorada a esquerda e centrada na vertical: acompanha a resolucao.
	var holder := MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	holder.offset_left = 48.0
	holder.offset_right = 520.0

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.GAP)
	panel.add_child(column)

	column.add_child(_build_logo())

	audio_modal = _build_audio_modal(hud)
	credits_modal = _build_credits_modal(hud)

	# Com progresso salvo, o botão principal diz "continuar".
	var play_text := "CONTINUAR" if Global.has_progress() else "JOGAR"
	var btn_play := UiButton.create(play_text, UiButton.Kind.PRIMARY, null, true)
	btn_play.pressed.connect(func(): get_tree().change_scene_to_file(WAR_MAP_SCENE))
	column.add_child(btn_play)

	var btn_lab := UiButton.create("LABORATÓRIO", UiButton.Kind.SECONDARY, null, true)
	btn_lab.tooltip_text = "Modo livre: teste a parábola sem inimigos, com tabela de pontos"
	btn_lab.pressed.connect(_open_lab)
	column.add_child(btn_lab)

	_teacher_btn = UiButton.create("", UiButton.Kind.SECONDARY, null, true)
	_teacher_btn.toggle_mode = true
	_teacher_btn.button_pressed = Global.teacher_mode
	_teacher_btn.tooltip_text = "Libera todas as bases e já mostra a conta da parábola"
	_teacher_btn.toggled.connect(_on_teacher_toggled)
	_on_teacher_toggled(Global.teacher_mode)
	column.add_child(_teacher_btn)

	# Áudio e créditos dividem uma linha para o painel caber na altura da tela.
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", UiTokens.GAP)
	column.add_child(pair)
	var btn_audio := UiButton.create("ÁUDIO", UiButton.Kind.SECONDARY, null, true)
	btn_audio.custom_minimum_size = Vector2(134, 52)
	btn_audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_audio.pressed.connect(audio_modal.open)
	pair.add_child(btn_audio)
	var btn_credits := UiButton.create("CRÉDITOS", UiButton.Kind.SECONDARY, null, true)
	btn_credits.custom_minimum_size = Vector2(134, 52)
	btn_credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_credits.pressed.connect(credits_modal.open)
	pair.add_child(btn_credits)

	reset_modal = _build_reset_modal(hud)
	var btn_reset := UiButton.create("RECOMEÇAR CAMPANHA", UiButton.Kind.SECONDARY, null, true)
	btn_reset.pressed.connect(reset_modal.open)
	btn_reset.visible = Global.has_progress()
	column.add_child(btn_reset)

	var btn_quit := UiButton.create("ABANDONAR POSTO", UiButton.Kind.SECONDARY, null, true)
	btn_quit.pressed.connect(func(): get_tree().quit())
	column.add_child(btn_quit)

	_buttons = [btn_play, btn_lab, _teacher_btn, btn_audio, btn_credits, btn_reset, btn_quit]
	_animate_entry(panel)
	btn_play.grab_focus.call_deferred()


func _open_lab() -> void:
	Global.lab_mode = true
	Global.reset_armor()
	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")


func _on_teacher_toggled(on: bool) -> void:
	Global.teacher_mode = on
	Global.save_game()
	_teacher_btn.text = "MODO PROFESSOR: " + ("LIGADO" if on else "DESLIGADO")
	_teacher_btn.add_theme_color_override("font_color", UiTokens.EDITABLE if on else UiTokens.TEXT)
	_teacher_btn.add_theme_color_override(
		"font_pressed_color", UiTokens.EDITABLE if on else UiTokens.TEXT
	)


## Logotipo: o nome em Jersey 10 grande, cruzado por um arco de parabola com o
## vertice marcado -- o mesmo desenho que a arena usa.
func _build_logo() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -10)

	var arc := Control.new()
	arc.custom_minimum_size = Vector2(0, 34)
	arc.draw.connect(_draw_logo_arc.bind(arc))
	box.add_child(arc)

	for word in ["BALLISTIC", "VECTOR"]:
		var title := Label.new()
		title.text = word
		title.theme_type_variation = &"DisplayLabel"
		title.add_theme_font_size_override("font_size", UiTokens.FONT_HERO)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)

	var sub := Label.new()
	sub.text = "a parábola no campo de batalha"
	sub.theme_type_variation = &"ResultLabel"
	sub.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	return box


func _draw_logo_arc(arc: Control) -> void:
	var w := arc.size.x
	var h := arc.size.y
	var prev := Vector2(0, h + 30)
	for i in range(1, 41):
		var t := float(i) / 40.0
		var p := Vector2(t * w, h + 30 - 4.0 * t * (1.0 - t) * (h + 18))
		if i % 2 == 0:
			arc.draw_line(prev, p, UiTokens.CALCULATED, 3.0)
		prev = p
	var top := Vector2(w * 0.5, 12)
	UiIcon.paint(arc, "vertex", Rect2(top - Vector2(10, 10), Vector2(20, 20)), UiTokens.CALCULATED)


## O painel surge e os botoes acendem em cascata, um depois do outro. So
## opacidade: dentro de um container, mexer em posicao seria desfeito pelo layout.
func _animate_entry(panel: Control) -> void:
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, UiTokens.ANIM)
	for i in range(_buttons.size()):
		var b: Button = _buttons[i]
		b.modulate.a = 0.0
		var bt := create_tween()
		bt.tween_interval(0.25 + i * 0.07)
		bt.tween_property(b, "modulate:a", 1.0, 0.18)


## Construido uma vez e reaproveitado.
func _build_audio_modal(parent: CanvasLayer) -> CanvasLayer:
	var modal = UiModalScript.new()
	parent.add_child(modal)

	modal.title_label.text = "AJUSTES DE ÁUDIO"
	modal.body.add_child(AudioSettingsScript.new())

	var btn_close := UiButton.create("VOLTAR AO COMANDO", UiButton.Kind.SECONDARY, null, true)
	btn_close.pressed.connect(modal.close)
	modal.body.add_child(btn_close)
	modal.closed.connect(func(): _buttons[3].grab_focus())
	return modal


## Confirmação antes de apagar o progresso; o foco começa no "não" para um
## Enter por engano não zerar tudo.
func _build_reset_modal(parent: CanvasLayer) -> CanvasLayer:
	var modal = UiModalScript.new()
	parent.add_child(modal)
	modal.title_label.text = "RECOMEÇAR?"
	var text := Label.new()
	text.text = "Todas as estrelas e bases conquistadas serão apagadas."
	text.text += "\nO ouro e a munição voltam ao início."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(420, 0)
	modal.body.add_child(text)
	var no := UiButton.create("NÃO, VOLTAR", UiButton.Kind.SECONDARY, null, true)
	no.pressed.connect(modal.close)
	modal.body.add_child(no)
	var yes := UiButton.create("SIM, APAGAR TUDO", UiButton.Kind.DANGER, null, true)
	yes.pressed.connect(
		func():
			Global.reset_progress()
			get_tree().reload_current_scene()
	)
	modal.body.add_child(yes)
	modal.visibility_changed.connect(_focus_if_visible.bind(modal, no))
	return modal


func _focus_if_visible(modal: CanvasLayer, button: Button) -> void:
	if modal.visible:
		button.grab_focus.call_deferred()


func _build_credits_modal(parent: CanvasLayer) -> CanvasLayer:
	var modal = UiModalScript.new()
	parent.add_child(modal)
	modal.title_label.text = "CRÉDITOS"
	modal.window.custom_minimum_size = Vector2(560, 0)

	var lines := [
		["Jogo", "Ballistic Vector — PAC #1, edutainment de funções quadráticas"],
		["Fontes", "VT323, Handjet (Rosetta Type) e Jersey 10 (Soft Type) — SIL OFL 1.1"],
		["Ícones", "Packs Kenney (kenney.nl) — CC0"],
		["Arte da interface", "Molduras, ícones, céu e terreno desenhados em código"],
		["Áudio", "Coleção Steampunk/Medieval licenciada para o projeto"],
	]
	for pair in lines:
		var head := Label.new()
		head.text = pair[0].to_upper()
		head.theme_type_variation = &"CaptionLabel"
		modal.body.add_child(head)
		var text := Label.new()
		text.text = pair[1]
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(500, 0)
		modal.body.add_child(text)

	var btn_close := UiButton.create("VOLTAR", UiButton.Kind.SECONDARY, null, true)
	btn_close.pressed.connect(modal.close)
	modal.body.add_child(btn_close)
	modal.closed.connect(func(): _buttons[4].grab_focus())
	return modal
