extends Control

var spawn_timer: float = 0.0
const BACKGROUND_PLANE = preload("res://assets/sprites/airplane_enemy_01.png")

# Pré-carregando os efeitos sonoros da sua pasta assets/audio
const SFX_HOVER = preload("res://assets/audio/menu_hover_.ogg")
const SFX_CLICK = preload("res://assets/audio/menu_click.ogg")
const MUSIC_BG = preload("res://assets/audio/musica_fundo.wav")

@onready var background: TextureRect = $Background
@onready var tank: Sprite2D = $Tank

var music_player: AudioStreamPlayer


func _ready() -> void:
	_setup_background_scaling()
	_setup_audio()
	_setup_ui()
	randomize()


func _setup_background_scaling() -> void:
	if background:
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		background.size = Vector2(1280, 720)
		background.position = Vector2(0, 0)

	if tank:
		tank.position = Vector2(580, 500)
		tank.scale = Vector2(0.9, 0.9)


func _setup_audio() -> void:
	# Cria e roda a música de fundo em loop automaticamente
	music_player = AudioStreamPlayer.new()
	music_player.stream = MUSIC_BG
	music_player.autoplay = true
	# Se o seu barramento se chamar "Music" ou "Master", o som vai sair perfeitamente
	if AudioServer.get_bus_index("Music") != -1:
		music_player.bus = "Music"
	add_child(music_player)


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
	var hud_canvas = CanvasLayer.new()
	add_child(hud_canvas)

	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.04, 0.03, 0.65)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = Vector2(50, 75)
	hud_canvas.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "BALLISTIC VECTOR"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	title.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer)

	var btn_play = _create_tactical_button("MAPA DE GUERRA")
	btn_play.pressed.connect(
		func():
			_play_sfx(SFX_CLICK)
			get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")
	)
	vbox.add_child(btn_play)

	var btn_audio = _create_tactical_button("CONFIGURAÇÕES DE ÁUDIO")
	btn_audio.pressed.connect(
		func():
			_play_sfx(SFX_CLICK)
			_open_audio_settings(hud_canvas)
	)
	vbox.add_child(btn_audio)

	var btn_quit = _create_tactical_button("ABANDONAR POSTO")
	btn_quit.pressed.connect(
		func():
			_play_sfx(SFX_CLICK)
			get_tree().quit()
	)
	vbox.add_child(btn_quit)


func _create_tactical_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 50)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 16)

	# Efeito sonoro de hover (quando o mouse passa em cima)
	btn.mouse_entered.connect(func(): _play_sfx(SFX_HOVER))

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.18, 0.13, 0.95)
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.border_color = Color(0.55, 0.42, 0.22, 1.0)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.shadow_color = Color(0, 0, 0, 0.5)
	normal.shadow_size = 6

	var hover = normal.duplicate()
	hover.bg_color = Color(0.35, 0.28, 0.18, 1.0)
	hover.border_color = Color(0.85, 0.68, 0.35, 1.0)

	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.15, 0.12, 0.08, 1.0)
	pressed.border_color = Color(0.4, 0.3, 0.15, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.9))

	return btn


func _play_sfx(stream: AudioStream) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	# Se o barramento SFX existir, usa ele; senão, toca no Master para garantir o som
	if AudioServer.get_bus_index("SFX") != -1:
		sfx.bus = "SFX"
	else:
		sfx.bus = "Master"
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _open_audio_settings(parent_canvas: CanvasLayer) -> void:
	var popup_bg = ColorRect.new()
	popup_bg.color = Color(0, 0, 0, 0.6)
	popup_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent_canvas.add_child(popup_bg)

	var window = PanelContainer.new()
	var win_style = StyleBoxFlat.new()
	win_style.bg_color = Color(0.15, 0.12, 0.1, 0.98)
	win_style.border_width_left = 2
	win_style.border_width_top = 2
	win_style.border_width_right = 2
	win_style.border_width_bottom = 2
	win_style.border_color = Color(0.6, 0.45, 0.25, 1.0)
	win_style.corner_radius_top_left = 8
	win_style.corner_radius_top_right = 8
	win_style.corner_radius_bottom_left = 8
	win_style.corner_radius_bottom_right = 8
	win_style.content_margin_left = 24
	win_style.content_margin_right = 24
	win_style.content_margin_top = 24
	win_style.content_margin_bottom = 24
	window.add_theme_stylebox_override("panel", win_style)
	window.custom_minimum_size = Vector2(400, 250)
	window.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup_bg.add_child(window)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	window.add_child(vbox)

	var lbl_title = Label.new()
	lbl_title.text = "AJUSTES DE ÁUDIO"
	lbl_title.add_theme_font_size_override("font_size", 20)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(lbl_title)

	vbox.add_child(_create_slider_row("Volume Geral", "Master"))
	vbox.add_child(_create_slider_row("Efeitos Sonoros", "SFX"))
	vbox.add_child(_create_slider_row("Trilha Sonora", "Music"))

	var btn_close = _create_tactical_button("VOLTAR AO COMANDO")
	btn_close.custom_minimum_size = Vector2(352, 44)
	btn_close.pressed.connect(
		func():
			_play_sfx(SFX_CLICK)
			popup_bg.queue_free()
	)
	vbox.add_child(btn_close)


func _create_slider_row(label_text: String, bus_name: String) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	container.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05

	# Se o barramento não existir no projeto, ele usa o Master para evitar erro e controlar o volume
	var target_bus = bus_name
	if AudioServer.get_bus_index(target_bus) == -1:
		target_bus = "Master"

	var idx = AudioServer.get_bus_index(target_bus)
	if idx != -1:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(idx))
	else:
		slider.value = 0.8

	slider.value_changed.connect(
		func(val):
			var current_idx = AudioServer.get_bus_index(target_bus)
			if current_idx != -1:
				AudioServer.set_bus_volume_db(current_idx, linear_to_db(val))
	)
	container.add_child(slider)

	return container
