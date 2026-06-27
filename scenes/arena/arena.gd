extends Node2D

# === Referências dos nós ===
@onready var player: Node2D = $Player
@onready var cannon: Node2D = $Player/Cannon
@onready var aim_line: Line2D = $Player/Cannon/AimLine
@onready var enemy: Node2D = $Enemy
@onready var bg: ColorRect = $BackgroundColorRect
# Variáveis de UI
var hud_canvas: CanvasLayer
var ammo_label: Label
var ammo_icon: Control
var ammo_name_label: Label
var power_label: Label
var hp_bar: ProgressBar
var enemies_label: Label

# === Configurações ===
const PLAYER_SPEED: float = 300.0       # Velocidade vertical do jogador
const ROTATION_SPEED: float = 1.5       # Velocidade de rotação do canhão (rad/s)
const ROTATION_STEP: float = 0.15       # Passo de rotação por clique nos botões (rad)
const MAX_CANNON_ANGLE: float = 1.225   # Ângulo máximo para cima (~69°)
const MIN_CANNON_ANGLE: float = -1.2    # Ângulo máximo para baixo

# === Sistema de Munição (Resources) ===
var ammo_types: Array[AmmoData] = []
var current_ammo_index: int = 0
var ammo_counts: Array[int] = []  # Quantidade restante de cada tipo

# === Variáveis de estado ===
var is_rotating_left: bool = false
var is_rotating_right: bool = false
var _tab_was_pressed: bool = false
var current_power: float = 1.0

# === Preload do script do projétil ===
const ProjectileScript = preload("res://scenes/arena/projectile.gd")

func _create_steampunk_panel() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.15, 0.1, 0.9)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.7, 0.5, 0.2, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 4
	return style

func _create_prompt(icon_tex: Texture2D, text: String) -> HBoxContainer:
	var hb = HBoxContainer.new()
	var tex_rect = TextureRect.new()
	tex_rect.texture = icon_tex
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.custom_minimum_size = Vector2(48, 48)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var lbl = Label.new()
	lbl.text = text
	var sys_font = SystemFont.new()
	sys_font.font_names = ["Georgia", "Times New Roman", "Serif"]
	lbl.add_theme_font_override("font", sys_font)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	
	hb.add_child(tex_rect)
	hb.add_child(lbl)
	return hb

func _setup_ui() -> void:
	hud_canvas = CanvasLayer.new()
	hud_canvas.name = "HUD"
	add_child(hud_canvas)
	
	var font = SystemFont.new()
	font.font_names = ["Georgia", "Times New Roman", "Serif"]
	
	# Painel Esquerdo (Controles e Força)
	var left_panel = PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel", _create_steampunk_panel())
	left_panel.position = Vector2(20, 20)
	left_panel.size = Vector2(220, 300)
	hud_canvas.add_child(left_panel)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 15)
	left_vbox.position = Vector2(10, 10)
	left_vbox.size = Vector2(200, 280)
	left_panel.add_child(left_vbox)
	
	var controls_lbl = Label.new()
	controls_lbl.text = "Controles"
	controls_lbl.add_theme_font_override("font", font)
	controls_lbl.add_theme_font_size_override("font_size", 24)
	controls_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	controls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(controls_lbl)
	
	left_vbox.add_child(_create_prompt(preload("res://assets/sprites/keyboard_mouse/keyboard_space.png"), "Atirar"))
	left_vbox.add_child(_create_prompt(preload("res://assets/sprites/keyboard_mouse/keyboard_tab.png"), "Trocar Municao"))
	left_vbox.add_child(_create_prompt(preload("res://assets/sprites/keyboard_mouse/keyboard_arrows_horizontal.png"), "Mirar"))
	left_vbox.add_child(_create_prompt(preload("res://assets/sprites/keyboard_mouse/keyboard_arrows_vertical.png"), "Forca"))
	
	var hs = HSeparator.new()
	left_vbox.add_child(hs)
	
	power_label = Label.new()
	power_label.text = "Forca: 100%"
	power_label.add_theme_font_override("font", font)
	power_label.add_theme_font_size_override("font_size", 22)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(power_label)
	
	var quit_btn = Button.new()
	quit_btn.text = "Desistir"
	
	var btn_tex = load("res://assets/sprites/ui_pack/Grey/Default/button_rectangle_depth_flat.png")
	var normal_style = StyleBoxTexture.new()
	normal_style.texture = btn_tex
	normal_style.content_margin_left = 12.0
	normal_style.content_margin_top = 8.0
	normal_style.content_margin_right = 12.0
	normal_style.content_margin_bottom = 8.0
	
	var hover_style = normal_style.duplicate()
	hover_style.modulate_color = Color(1.1, 1.05, 0.95)
	var pressed_style = normal_style.duplicate()
	pressed_style.modulate_color = Color(0.85, 0.8, 0.75)
	
	quit_btn.add_theme_stylebox_override("normal", normal_style)
	quit_btn.add_theme_stylebox_override("hover", hover_style)
	quit_btn.add_theme_stylebox_override("pressed", pressed_style)
	quit_btn.add_theme_font_override("font", font)
	quit_btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.0))
	quit_btn.add_theme_color_override("font_hover_color", Color(0.15, 0.08, 0.0))
	quit_btn.add_theme_color_override("font_pressed_color", Color(0.15, 0.08, 0.0))
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.icon = load("res://assets/sprites/icons/exit.png")
	quit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	quit_btn.pressed.connect(_on_quit)
	left_vbox.add_child(quit_btn)

	# Painel Inferior (Munição e Vida)
	var bottom_panel = PanelContainer.new()
	bottom_panel.add_theme_stylebox_override("panel", _create_steampunk_panel())
	bottom_panel.position = Vector2(440, 620)
	bottom_panel.size = Vector2(400, 80)
	hud_canvas.add_child(bottom_panel)
	
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 20)
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.size = Vector2(400, 80)
	bottom_panel.add_child(bottom_hbox)
	
	var ammo_info_vbox = VBoxContainer.new()
	ammo_info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_child(ammo_info_vbox)
	
	var ammo_hbox = HBoxContainer.new()
	ammo_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_info_vbox.add_child(ammo_hbox)
	
	ammo_icon = load("res://scripts/ammo_icon.gd").new()
	ammo_icon.custom_minimum_size = Vector2(40, 40)
	ammo_hbox.add_child(ammo_icon)
	
	ammo_label = Label.new()
	ammo_label.add_theme_font_override("font", font)
	ammo_label.add_theme_font_size_override("font_size", 28)
	ammo_hbox.add_child(ammo_label)
	
	ammo_name_label = Label.new()
	ammo_name_label.add_theme_font_override("font", font)
	ammo_name_label.add_theme_font_size_override("font_size", 16)
	ammo_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_info_vbox.add_child(ammo_name_label)
	
	var vs = VSeparator.new()
	bottom_hbox.add_child(vs)
	
	var hp_vbox = VBoxContainer.new()
	hp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hp_vbox.custom_minimum_size = Vector2(150, 0)
	bottom_hbox.add_child(hp_vbox)
	
	var hp_lbl = Label.new()
	hp_lbl.text = "Armadura"
	hp_lbl.add_theme_font_override("font", font)
	hp_lbl.add_theme_font_size_override("font_size", 18)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_vbox.add_child(hp_lbl)
	
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(150, 20)
	hp_bar.value = 100
	hp_bar.show_percentage = true
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.2, 0.0, 0.0)
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = Color(0.8, 0.2, 0.2)
	hp_bar.add_theme_stylebox_override("background", sb_bg)
	hp_bar.add_theme_stylebox_override("fill", sb_fg)
	hp_bar.add_theme_font_override("font", font)
	hp_vbox.add_child(hp_bar)

	# Painel Superior (Inimigos)
	var top_panel = PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", _create_steampunk_panel())
	top_panel.position = Vector2(540, 10)
	top_panel.size = Vector2(200, 60)
	hud_canvas.add_child(top_panel)
	
	enemies_label = Label.new()
	enemies_label.text = "Inimigos: 1"
	enemies_label.add_theme_font_override("font", font)
	enemies_label.add_theme_font_size_override("font_size", 24)
	enemies_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemies_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemies_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_panel.add_child(enemies_label)

func _ready() -> void:
	randomize()
	_setup_ui()
	# Fundo aleatório
	if bg:
		bg.color = Color(
			randf_range(0.15, 0.6),
			randf_range(0.15, 0.6),
			randf_range(0.15, 0.6),
			1.0
		)
	
	# Carregar munições dos Resources
	_load_ammo_types()
	_update_hud()
	_update_power_hud()
	_update_aim_line()
	
	AudioManager.play_bgm("res://assets/audio/Battle.mp3")

func _load_ammo_types() -> void:
	# Carrega todos os tipos de munição definidos nos .tres
	var enferrujada = load("res://assets/resources/ammo_enferrujada.tres") as AmmoData
	var perfurante = load("res://assets/resources/ammo_perfurante.tres") as AmmoData
	
	ammo_types.append(enferrujada)
	ammo_types.append(perfurante)
	
	# Inicializar contadores com o inventário global
	for ammo in ammo_types:
		if Global.ammo_inventory.has(ammo.ammo_name):
			ammo_counts.append(Global.ammo_inventory[ammo.ammo_name])
		else:
			ammo_counts.append(0)

func _get_current_ammo() -> AmmoData:
	return ammo_types[current_ammo_index]

func _process(delta: float) -> void:
	# === Controle de Força (setas cima/baixo) ===
	var power_dir: float = 0.0
	if Input.is_action_pressed("ui_up"):
		power_dir += 1.0
	if Input.is_action_pressed("ui_down"):
		power_dir -= 1.0
	
	if power_dir != 0.0:
		current_power += power_dir * 0.5 * delta
		current_power = clamp(current_power, 0.05, 1.0)
		_update_power_hud()
		_update_aim_line()

	# === Rotação do canhão (setas esquerda/direita ou botões) ===
	var rot_dir: float = 0.0
	if Input.is_action_pressed("ui_left") or is_rotating_left:
		rot_dir -= 1.0
	if Input.is_action_pressed("ui_right") or is_rotating_right:
		rot_dir += 1.0
	
	if rot_dir != 0.0:
		var ammo = _get_current_ammo()
		var speed_mult: float = 0.2 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		# Ajustar a velocidade de rotação para manter a sensação consistente:
		# Munições mais fortes giram mais devagar.
		var impulse_compensation: float = 500.0 / max(ammo.impulse, 10.0)
		
		cannon.rotation += rot_dir * (ROTATION_SPEED * speed_mult * impulse_compensation) * delta
		cannon.rotation = clamp(cannon.rotation, MIN_CANNON_ANGLE, MAX_CANNON_ANGLE)
		_update_aim_line()
	
	# === Disparo com espaço ===
	if Input.is_action_just_pressed("ui_accept"):
		_fire_projectile()
	
	# === Trocar munição com Tab ===
	if Input.is_key_pressed(KEY_TAB) == false and _tab_was_pressed:
		_on_switch_ammo()
	_tab_was_pressed = Input.is_key_pressed(KEY_TAB)

# === Atualiza a linha de mira com curvatura gravitacional ===
# Simula em espaço GLOBAL (igual ao projétil real) e converte para local do canhão
func _update_aim_line() -> void:
	var ammo = _get_current_ammo()
	var points: PackedVector2Array = PackedVector2Array()
	
	# Ponto de partida: ponta do cano em global
	var barrel_tip_global: Vector2 = cannon.to_global(Vector2(50, 0))
	
	# Velocidade inicial em global (mesma do projétil real)
	var fire_direction: Vector2 = Vector2.RIGHT.rotated(cannon.global_rotation)
	var sim_vel: Vector2 = fire_direction * (ammo.impulse * current_power)
	var sim_pos: Vector2 = barrel_tip_global
	
	var dt: float = 0.02  # Passo de simulação
	var steps: int = 200  # Passos suficientes para cobrir toda a tela
	
	# Primeiro ponto (ponta do cano em local)
	points.append(cannon.to_local(sim_pos))
	
	for i in range(steps):
		# Gravidade age no Y global (igual ao projétil)
		sim_vel.y += ammo.gravity * dt
		sim_pos += sim_vel * dt
		
		# Parar apenas se saiu lateralmente ou por baixo da tela
		if sim_pos.x > 1300 or sim_pos.x < -50 or sim_pos.y > 740:
			break
		
		# Converter ponto global para local do canhão (para a Line2D)
		points.append(cannon.to_local(sim_pos))
	
	aim_line.points = points

# === Disparo do projétil ===
func _fire_projectile() -> void:
	var ammo = _get_current_ammo()
	
	if ammo_counts[current_ammo_index] <= 0:
		return
	
	ammo_counts[current_ammo_index] -= 1
	Global.ammo_inventory[ammo.ammo_name] = ammo_counts[current_ammo_index]
	_update_hud()
	
	AudioManager.play_sfx("res://assets/audio/cannon_fire.ogg")
	
	# Criar o projétil como um ColorRect dentro de um Node2D
	var projectile = Node2D.new()
	projectile.set_script(ProjectileScript)
	
	# Posição global da ponta do cano
	var barrel_tip_local = Vector2(50, 0)
	var barrel_tip_global = cannon.to_global(barrel_tip_local)
	projectile.position = barrel_tip_global
	
	# Direção do disparo (ângulo global do canhão + desvio de precisão)
	var angle_deviation = randf_range(-1.0, 1.0) * (1.0 - ammo.precision) * 0.12
	var fire_direction = Vector2.RIGHT.rotated(cannon.global_rotation + angle_deviation)
	
	# Configurar o projétil com dados do Resource
	projectile.velocity = fire_direction * (ammo.impulse * current_power)
	projectile.gravity = ammo.gravity
	projectile.precision = ammo.precision
	projectile.bullet_color = ammo.color
	projectile.enemy_node = enemy
	
	# Adicionar à cena
	add_child(projectile)

# === Atualiza toda a HUD de munição ===
func _update_hud() -> void:
	var ammo = _get_current_ammo()
	if ammo_label:
		ammo_label.text = "x" + str(ammo_counts[current_ammo_index])
	if ammo_icon and ammo_icon.has_method("queue_redraw"):
		ammo_icon.ammo_color = ammo.color
		ammo_icon.queue_redraw()
	if ammo_name_label:
		ammo_name_label.text = ammo.ammo_name

func _update_power_hud() -> void:
	if power_label:
		power_label.text = "Forca: " + str(round(current_power * 100)) + "%"

# === Troca de munição ===
func _on_switch_ammo() -> void:
	current_ammo_index = (current_ammo_index + 1) % ammo_types.size()
	_update_hud()
	_update_aim_line()

# === Callbacks dos botões da HUD ===
func _on_rotate_left() -> void:
	var ammo = _get_current_ammo()
	var step_mult: float = 0.2 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var impulse_compensation: float = 500.0 / max(ammo.impulse, 10.0)
	cannon.rotation -= (ROTATION_STEP * step_mult * impulse_compensation)
	cannon.rotation = clamp(cannon.rotation, MIN_CANNON_ANGLE, MAX_CANNON_ANGLE)
	_update_aim_line()

func _on_rotate_right() -> void:
	var ammo = _get_current_ammo()
	var step_mult: float = 0.2 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var impulse_compensation: float = 500.0 / max(ammo.impulse, 10.0)
	cannon.rotation += (ROTATION_STEP * step_mult * impulse_compensation)
	cannon.rotation = clamp(cannon.rotation, MIN_CANNON_ANGLE, MAX_CANNON_ANGLE)
	_update_aim_line()

func _on_fire() -> void:
	_fire_projectile()

func _on_power_up() -> void:
	current_power += 0.05
	current_power = clamp(current_power, 0.05, 1.0)
	_update_power_hud()
	_update_aim_line()

func _on_power_down() -> void:
	current_power -= 0.05
	current_power = clamp(current_power, 0.05, 1.0)
	_update_power_hud()
	_update_aim_line()

func _on_quit() -> void:
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")
