class_name StoryIntro
extends CanvasLayer
## Abertura de enredo: 4 telas, cada uma com uma ilustracao montada com os
## sprites do jogo e uma frase. Tela cheia e opaca, porque o tanque do menu
## continua atirando atras. Nao grava nada no save: quem escuta `finished`
## decide (o menu marca o enredo como visto).
##
## `finished(skipped)` sai uma unica vez por abertura: `false` ao terminar a
## quarta tela, `true` em PULAR ou Esc.

signal finished(skipped: bool)

## Texto aprovado, literal (about-task.md). Nao reescrever.
const LINES: Array[String] = [
	(
		"O Comando Norte tomou o arquipélago em uma noite: "
		+ "um pulso eletromagnético queimou todos os computadores de mira da frota."
	),
	(
		"As fortalezas que a Engenheira Ada projetou viraram castelos deles, "
		+ "blindados contra o pulso. Os nossos canhões viraram sucata."
	),
	(
		"Ada consertou o último que restou: o seu tanque. Sem computador, "
		+ "ele só dispara com a conta certa."
	),
	"Ela sabe onde cada castelo falha. O resto é cálculo.",
]

const NEXT_LABEL := "PRÓXIMO →"
const START_LABEL := "COMEÇAR"
const SKIP_LABEL := "PULAR"

const STAGE_SIZE := Vector2(880, 300)
const TEXT_WIDTH := 820.0
const FLASH_PEAK := 0.85
const FLASH_TIME := 0.6
const ARC_STEPS := 40

const CASTLE := preload("res://assets/sprites/cartography/Default/castle.png")
const CASTLE_WIDE := preload("res://assets/sprites/cartography/Default/castleWide.png")
const TOWER := preload("res://assets/sprites/cartography/Default/towerTall.png")
const PLANE := preload("res://assets/sprites/airplane_enemy_01.png")
const BOSS := preload("res://assets/sprites/boss.png")
const TANK := preload("res://assets/sprites/tank_player.png")
const BARREL := preload("res://assets/sprites/tank_barrel.png")

var _index := 0
var _done := true
var _stage: Control
var _line_label: Label
var _next_btn: Button
var _flash: ColorRect
var _flash_tween: Tween


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


## Abre na tela 1, qualquer que seja o estado anterior.
func open() -> void:
	_index = 0
	_done = false
	visible = true
	_show_screen()
	_next_btn.grab_focus.call_deferred()


func advance() -> void:
	if _done:
		return
	if _index >= LINES.size() - 1:
		_finish(false)
		return
	_index += 1
	_show_screen()


func skip() -> void:
	if _done:
		return
	_finish(true)


func current_index() -> int:
	return _index


## Esc pula. Enter e Espaco avancam pelo botao com foco, entao nao sao tratados
## aqui: tratar de novo avancaria duas telas de uma vez.
func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()


func _finish(skipped: bool) -> void:
	_done = true
	visible = false
	Narrator.stop()
	finished.emit(skipped)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = UiTokens.NIGHT_900
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.GAP * 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	_stage = Control.new()
	_stage.custom_minimum_size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	column.add_child(_stage)

	_line_label = Label.new()
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	column.add_child(_line_label)

	_next_btn = UiButton.create(NEXT_LABEL, UiButton.Kind.PRIMARY, null, true)
	_next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next_btn.pressed.connect(advance)
	column.add_child(_next_btn)

	var top := MarginContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["margin_top", "margin_right"]:
		top.add_theme_constant_override(side, UiTokens.GAP * 2)
	backdrop.add_child(top)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var skip_btn := UiButton.create(SKIP_LABEL, UiButton.Kind.SECONDARY, null, true)
	skip_btn.pressed.connect(skip)
	row.add_child(skip_btn)

	# Por ultimo, para ficar por cima de tudo.
	_flash = ColorRect.new()
	_flash.color = UiTokens.PULSE_FLASH
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(_flash)


func _on_backdrop_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		advance()


func _show_screen() -> void:
	_line_label.text = LINES[_index]
	_line_label.add_theme_font_size_override(
		"font_size", UiTokens.FONT_XL if Global.big_text else UiTokens.FONT_LG
	)
	_next_btn.text = START_LABEL if _index == LINES.size() - 1 else NEXT_LABEL
	_build_illustration(_index)
	if _flash_tween:
		_flash_tween.kill()
	_flash.modulate.a = 0.0
	if _index == 0:
		_play_flash()
	Narrator.speak(LINES[_index])


## Clarao do pulso: sobe rapido e some, so na primeira tela.
func _play_flash() -> void:
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", FLASH_PEAK, FLASH_TIME * 0.25)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, FLASH_TIME * 0.75)


func _build_illustration(index: int) -> void:
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	match index:
		0:
			_illustrate_pulse()
		1:
			_illustrate_enemy_castles()
		2:
			_illustrate_repaired_tank()
		_:
			_illustrate_plan()


## Tela 1: tres ilhas com castelos e dois avioes sob o pulso.
func _illustrate_pulse() -> void:
	_island(Vector2(180, 250), 200.0)
	_sprite(CASTLE, Vector2(180, 190), Vector2(128, 128))
	_island(Vector2(440, 250), 260.0)
	_sprite(CASTLE_WIDE, Vector2(440, 205), Vector2(192, 96))
	_island(Vector2(700, 250), 200.0)
	_sprite(TOWER, Vector2(700, 190), Vector2(128, 128))
	_sprite(PLANE, Vector2(280, 60), Vector2(120, 66))
	_sprite(PLANE, Vector2(600, 90), Vector2(120, 66), true)


## Tela 2: tres fortalezas blindadas e o canhao antigo caido, sucata.
func _illustrate_enemy_castles() -> void:
	for x in [180.0, 440.0, 700.0]:
		_sprite(BOSS, Vector2(x, 140), Vector2(200, 110))
		var shield := UiIcon.make("shield", UiTokens.CALCULATED, 56.0)
		shield.position = Vector2(x, 130) - Vector2(28, 28)
		_stage.add_child(shield)
	var scrap := _sprite(BARREL, Vector2(440, 268), Vector2(170, 30))
	scrap.rotation_degrees = 100.0
	scrap.self_modulate = UiTokens.TEXT_DISABLED


## Tela 3: a Ada ao lado do tanque que ela consertou.
func _illustrate_repaired_tank() -> void:
	_portrait("proud", Vector2(230, 150), 200.0)
	_sprite(TANK, Vector2(600, 160), Vector2(320, 175))


## Tela 4: a Ada calcula; a parabola tracejada leva do tanque ao castelo.
func _illustrate_plan() -> void:
	_portrait("thinking", Vector2(110, 160), 150.0)
	_sprite(TANK, Vector2(270, 220), Vector2(200, 110))
	_sprite(BOSS, Vector2(750, 220), Vector2(180, 100))
	var arc := Control.new()
	arc.position = Vector2(310, 60)
	arc.size = Vector2(380, 150)
	arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arc.draw.connect(_draw_arc.bind(arc))
	_stage.add_child(arc)


func _sprite(tex: Texture2D, center: Vector2, size: Vector2, flip := false) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.flip_h = flip
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = size
	rect.pivot_offset = size * 0.5
	rect.position = center - size * 0.5
	_stage.add_child(rect)
	return rect


func _portrait(expression: String, center: Vector2, side: float) -> void:
	var ada := AdaPortrait.new()
	ada.expression = expression
	ada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ada.size = Vector2(side, side)
	ada.position = center - ada.size * 0.5
	_stage.add_child(ada)


## Ilha: elipse chata de terra embaixo do castelo.
func _island(center: Vector2, width: float) -> void:
	var panel := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.OLIVE_DARK
	box.set_corner_radius_all(40)
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(width, 44)
	panel.position = center - panel.size * 0.5
	_stage.add_child(panel)


## Mesma parabola tracejada do logo do menu (menu_play.gd `_draw_logo_arc`).
func _draw_arc(arc: Control) -> void:
	var w := arc.size.x
	var h := arc.size.y
	var prev := Vector2(0, h)
	for i in range(1, ARC_STEPS + 1):
		var t := float(i) / ARC_STEPS
		var p := Vector2(t * w, h - 4.0 * t * (1.0 - t) * h)
		if i % 2 == 0:
			arc.draw_line(prev, p, UiTokens.CALCULATED, 3.0)
		prev = p
	var top := Vector2(w * 0.5, 0)
	UiIcon.paint(arc, "vertex", Rect2(top - Vector2(10, 10), Vector2(20, 20)), UiTokens.CALCULATED)
