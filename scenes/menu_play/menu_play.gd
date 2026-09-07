extends Control

const BACKGROUND_PLANE = preload("res://assets/sprites/airplane_enemy_01.png")
const UiModalScript = preload("res://scripts/ui/ui_modal.gd")
const AudioSettingsScript = preload("res://scripts/ui/audio_settings.gd")

const MUSIC_BG := "res://assets/audio/musica_fundo.wav"
const WAR_MAP_SCENE := "res://scenes/war_map/war_map.tscn"

@onready var background: TextureRect = $Background
@onready var tank: Sprite2D = $Tank

var spawn_timer: float = 0.0
var audio_modal: CanvasLayer


func _ready() -> void:
	_setup_background_scaling()
	# Antes esta cena criava o proprio AudioStreamPlayer, e era a unica a fazer
	# isso. Ao voltar do mapa de guerra a trilha do AudioManager continuava
	# tocando e a local comecava por cima, sobrepostas.
	AudioManager.play_bgm(MUSIC_BG)
	_setup_ui()
	randomize()


func _setup_background_scaling() -> void:
	if background:
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if tank:
		tank.position = Vector2(580, 500)
		tank.scale = Vector2(0.9, 0.9)


func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_background_plane()
		spawn_timer = randf_range(5.0, 10.0)


func _spawn_background_plane() -> void:
	var plane = Sprite2D.new()
	plane.texture = BACKGROUND_PLANE
	plane.scale = Vector2(0.015, 0.015)
	plane.modulate = Color(0.2, 0.2, 0.2, 0.7)
	plane.position = Vector2(-100, randf_range(80, 220))
	add_child(plane)

	var tween = create_tween()
	var travel_time = randf_range(15.0, 25.0)
	tween.tween_property(plane, "position:x", 1400.0, travel_time)
	tween.tween_callback(plane.queue_free)


func _setup_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	# Sem stylebox inline: o PanelContainer ja vem pintado pelo Theme global.
	var panel := PanelContainer.new()
	panel.position = Vector2(50, 75)
	hud.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.GAP_LG)
	panel.add_child(column)

	var title := Label.new()
	title.text = "BALLISTIC VECTOR"
	title.add_theme_font_size_override("font_size", UiTokens.FONT_DISPLAY)
	title.add_theme_color_override("font_color", UiTokens.AMBER)
	title.add_theme_color_override("font_outline_color", UiTokens.AMBER_OUTLINE)
	title.add_theme_constant_override("outline_size", UiTokens.OUTLINE_SIZE)
	column.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	column.add_child(spacer)

	audio_modal = _build_audio_modal(hud)

	var btn_play := UiButton.create("MAPA DE GUERRA")
	btn_play.pressed.connect(func(): get_tree().change_scene_to_file(WAR_MAP_SCENE))
	column.add_child(btn_play)

	var btn_audio := UiButton.create("CONFIGURAÇÕES DE ÁUDIO")
	btn_audio.pressed.connect(audio_modal.open)
	column.add_child(btn_audio)

	var btn_quit := UiButton.create("ABANDONAR POSTO")
	btn_quit.pressed.connect(func(): get_tree().quit())
	column.add_child(btn_quit)


## Construido uma vez e reaproveitado. A versao antiga montava a janela inteira a
## cada clique e a centralizava com PRESET_CENTER, que congela offsets calculados
## uma unica vez -- o painel saia do lugar em qualquer resolucao fora da de
## projeto. O UiModal centraliza com CenterContainer, que recalcula sozinho.
func _build_audio_modal(parent: CanvasLayer) -> CanvasLayer:
	var modal = UiModalScript.new()
	parent.add_child(modal)

	modal.title_label.text = "AJUSTES DE ÁUDIO"
	modal.body.add_child(AudioSettingsScript.new())

	var btn_close := UiButton.create("VOLTAR AO COMANDO")
	btn_close.pressed.connect(modal.close)
	modal.body.add_child(btn_close)

	return modal
