extends Control

var spawn_timer: float = 0.0
const BACKGROUND_PLANE = preload("res://assets/sprites/airplane_enemy_01.png") 

@onready var background: TextureRect = $Background
@onready var tank: Sprite2D = $Tank

func _ready() -> void:
	_setup_background_scaling()
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
	
	# Painel leve e translúcido para dar contraste e legibilidade perfeita ao menu
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.04, 0.03, 0.65) # Fundo escuro suave com transparência
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
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)
	
	# Título principal imponente
	var title = Label.new()
	title.text = "BALLISTIC VECTOR"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	title.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title)
	
	# Espaçador limpo
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Botões táticos estilizados
	var btn_play = _create_tactical_button("MAPA DE GUERRA")
	btn_play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn"))
	vbox.add_child(btn_play)
	
	var btn_quit = _create_tactical_button("ABANDONAR POSTO")
	btn_quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(btn_quit)

func _create_tactical_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 52)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 18)
	
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
