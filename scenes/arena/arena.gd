extends Node2D

# =============================================================================
#  Arena de Combate — arena.gd
#  Gerencia o combate por turnos: canhão do jogador, inimigos dinâmicos,
#  obstáculos, sistema de fases e HUD.
# =============================================================================

# === Referências dos nós (cena) ===
@onready var player: Node2D = $Player
@onready var cannon: Node2D = $Player/Cannon
@onready var aim_line: Line2D = $Player/Cannon/AimLine
@onready var bg: ColorRect = $BackgroundColorRect
@onready var obstacles_node: Node2D = $Obstacles


# === Variáveis de UI ===
var hud_canvas: CanvasLayer
var ammo_label: Label
var ammo_icon: Control
var ammo_name_label: Label
var power_label: Label
var armor_bar: ProgressBar
var stage_label: Label
var next_stage_btn: Button
var return_btn: Button
var quit_btn: Button

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

# === Sistema de inimigos ===
var active_enemies: Array = []  # Lista de inimigos vivos na cena
var stage_cleared: bool = false  # Se todos os inimigos morreram nesta fase

# === Polígonos de obstáculos em coordenadas globais (calculados uma vez) ===
var _obstacle_polygons_cache: Array = []

# === Preload dos scripts ===
const ProjectileScript = preload("res://scenes/arena/projectile.gd")
const AirplaneScript = preload("res://scenes/arena/airplane_enemy.gd")

# === Configuração de inimigos por fase ===
# Cada fase tem: boss_hp, num_airplanes, airplane_hp
const STAGE_CONFIG: Array = [
	{"boss_hp": 3, "num_airplanes": 2, "airplane_hp": 1},
	{"boss_hp": 3, "num_airplanes": 3, "airplane_hp": 1},
	{"boss_hp": 3, "num_airplanes": 3, "airplane_hp": 2},
]


func _ready() -> void:
	randomize()
	# Fundo aleatório
	if bg:
		bg.color = Color(
			randf_range(0.15, 0.6),
			randf_range(0.15, 0.6),
			randf_range(0.15, 0.6),
			1.0
		)

	# Calcular polígonos de obstáculos em coordenadas globais (uma vez)
	_cache_obstacle_polygons()

	# Carregar munições dos Resources
	_load_ammo_types()

	_setup_ui()
	AudioManager.play_bgm("res://assets/audio/Battle.mp3")

	# Inicializar HUD
	_update_hud()
	_update_power_hud()
	_update_aim_line()
	_update_armor_hud()
	_update_stage_label()

	# Esconder botão de próxima fase inicialmente
	if next_stage_btn:
		next_stage_btn.visible = false

	# Spawnar inimigos para a fase atual
	_spawn_enemies()


# === Calcular polígonos dos obstáculos em coordenadas globais ===
func _cache_obstacle_polygons() -> void:
	_obstacle_polygons_cache.clear()
	if not obstacles_node:
		return
	for child in obstacles_node.get_children():
		if child is StaticBody2D:
			var col_poly = child.get_node_or_null("CollisionPolygon2D")
			if col_poly and col_poly is CollisionPolygon2D:
				var local_poly: PackedVector2Array = col_poly.polygon
				var global_poly: PackedVector2Array = PackedVector2Array()
				for point in local_poly:
					# Converter ponto local do StaticBody2D para global
					global_poly.append(child.to_global(point))
				_obstacle_polygons_cache.append(global_poly)


# === Retorna os polígonos de obstáculos (usado pelos projéteis inimigos) ===
func get_obstacle_polygons() -> Array:
	return _obstacle_polygons_cache


# === Carregar tipos de munição dos Resources ===
func _load_ammo_types() -> void:
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


# =============================================================================
#  SPAWNING DE INIMIGOS
# =============================================================================
func _spawn_enemies() -> void:
	active_enemies.clear()
	var stage = Global.current_stage
	var config = STAGE_CONFIG[clampi(stage, 0, STAGE_CONFIG.size() - 1)]

	# --- Spawnar o Boss ---
	var boss = _create_boss(config.boss_hp)
	boss.position = Vector2(1100, 695)
	add_child(boss)
	active_enemies.append(boss)

	# --- Spawnar aviões ---
	for i in range(config.num_airplanes):
		var airplane = AirplaneScript.new()
		airplane.name = "Airplane"
		airplane.position = Vector2(
			randf_range(750.0, 1200.0),
			randf_range(200.0, 480.0)
		)
		airplane.hp = config.airplane_hp
		airplane.player_ref = player
		add_child(airplane)
		active_enemies.append(airplane)


# --- Cria o nó do Boss (Node2D com ColorRect, sem script de movimento) ---
func _create_boss(boss_hp: int) -> Node2D:
	var boss = Node2D.new()
	boss.name = "Boss"

	# Visual do boss (retângulo maior, vermelho escuro)
	var body = ColorRect.new()
	body.name = "Body"
	body.size = Vector2(60, 50)
	body.position = Vector2(-30, -25)
	body.color = Color(0.7, 0.15, 0.15, 1.0)
	boss.add_child(body)

	# Label do boss
	var label = Label.new()
	label.name = "BossLabel"
	label.text = "BOSS"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-20, -10)
	label.size = Vector2(40, 20)
	boss.add_child(label)

	# Variáveis de HP no boss (usamos set_meta para não precisar de script)
	boss.set_meta("hp", boss_hp)
	boss.set_meta("max_hp", boss_hp)
	boss.set_meta("original_color", body.color)
	boss.set_meta("is_boss", true)

	return boss


# =============================================================================
#  LOOP PRINCIPAL (_process)
# =============================================================================
func _process(delta: float) -> void:
	# Não processar input se a fase foi limpa
	if stage_cleared:
		return

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


# =============================================================================
#  LINHA DE MIRA
# =============================================================================
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

		# Parar se saiu lateralmente ou por baixo da tela
		if sim_pos.x > 1300 or sim_pos.x < -50 or sim_pos.y > 740:
			break

		# Parar se entrou em um obstáculo
		var hit_obstacle = false
		for poly in _obstacle_polygons_cache:
			if Geometry2D.is_point_in_polygon(sim_pos, poly):
				hit_obstacle = true
				break
		if hit_obstacle:
			points.append(cannon.to_local(sim_pos))
			break

		# Converter ponto global para local do canhão (para a Line2D)
		points.append(cannon.to_local(sim_pos))

	aim_line.points = points


# =============================================================================
#  DISPARO DO PROJÉTIL
# =============================================================================
func _fire_projectile() -> void:
	var ammo = _get_current_ammo()

	if ammo_counts[current_ammo_index] <= 0:
		return

	AudioManager.play_sfx("res://assets/audio/cannon_fire.ogg")
	ammo_counts[current_ammo_index] -= 1
	Global.ammo_inventory[ammo.ammo_name] = ammo_counts[current_ammo_index]
	_update_hud()

	# Criar o projétil usando o Script carregado
	var projectile = ProjectileScript.new()

	# Posição global da ponta do cano
	var barrel_tip_local = Vector2(50, 0)
	var barrel_tip_global = cannon.to_global(barrel_tip_local)
	projectile.position = barrel_tip_global

	# Penalidade de precisão baseada na armadura
	var armor_penalty = (1.0 - Global.player_armor / Global.max_player_armor) * 0.15

	# Direção do disparo (ângulo global do canhão + desvio de precisão)
	var total_imprecision = (1.0 - ammo.precision) * 0.12 + armor_penalty
	var angle_deviation = randf_range(-1.0, 1.0) * total_imprecision
	var fire_direction = Vector2.RIGHT.rotated(cannon.global_rotation + angle_deviation)

	# Configurar o projétil com dados do Resource
	projectile.velocity = fire_direction * (ammo.impulse * current_power)
	projectile.gravity = ammo.gravity
	projectile.precision = ammo.precision
	projectile.bullet_color = ammo.color
	projectile.damage = ammo.damage
	projectile.enemy_nodes = active_enemies.duplicate()
	projectile.obstacle_polygons = _obstacle_polygons_cache
	projectile.is_enemy_projectile = false

	# Adicionar à cena
	add_child(projectile)


# =============================================================================
#  CALLBACKS DE COLISÃO (chamados pelo projectile.gd)
# =============================================================================

# --- Projétil do jogador acertou um inimigo ---
func on_enemy_hit(enemy: Node2D, dmg: int) -> void:
	if not enemy or not is_instance_valid(enemy):
		return

	# Verificar se o inimigo tem o método take_damage (aviões com script)
	if enemy.has_method("take_damage"):
		enemy.take_damage(dmg)
	else:
		# Boss sem script — sempre perde 1 HP por tiro (3 tiros pra morrer)
		var current_hp = enemy.get_meta("hp", 0)
		current_hp -= 1
		enemy.set_meta("hp", current_hp)
		_flash_enemy(enemy)
		if current_hp <= 0:
			on_enemy_destroyed(enemy)
			enemy.queue_free()


# --- Projétil inimigo acertou o jogador ---
func on_player_hit(dmg: int) -> void:
	Global.player_armor -= dmg
	Global.player_armor = max(Global.player_armor, 0.0)
	_update_armor_hud()
	_flash_player()

	# Verificar game over
	if Global.player_armor <= 0:
		get_tree().change_scene_to_file("res://scenes/game_over/game_over.tscn")


# --- Inimigo foi destruído (chamado pelo airplane_enemy.gd ou internamente) ---
func on_enemy_destroyed(enemy: Node2D) -> void:
	if enemy.name == "Boss":
		Global.money += 150
	else:
		Global.money += 25
		
	active_enemies.erase(enemy)
	# Limpar referências inválidas
	var still_alive: Array = []
	for e in active_enemies:
		if e and is_instance_valid(e):
			still_alive.append(e)
	active_enemies = still_alive

	if active_enemies.size() == 0:
		_on_stage_cleared()


# =============================================================================
#  SISTEMA DE FASES
# =============================================================================

# --- Fase limpa — todos os inimigos mortos ---
func _on_stage_cleared() -> void:
	stage_cleared = true
	# Recompensar o jogador
	Global.money += 250

	# Mostrar botão de próxima fase
	if next_stage_btn:
		if Global.current_stage >= 2:
			next_stage_btn.text = "✓ Vitória!"
		next_stage_btn.visible = true


# --- Botão "Próxima Fase" pressionado ---
func _on_next_stage() -> void:
	if Global.current_stage < 2:
		# Avançar para a próxima fase
		Global.current_stage += 1
		Global.update_base_cleared(Global.current_base_id, Global.current_stage)
		# Recarregar a cena da arena
		get_tree().reload_current_scene()
	else:
		# Fase final concluída — base totalmente limpa
		Global.update_base_cleared(Global.current_base_id, 3)
		get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")


# --- Botão "Voltar ao Mapa" pressionado ---
func _on_return_to_map() -> void:
	# Salvar progresso atual e voltar ao mapa
	Global.update_base_cleared(Global.current_base_id, Global.current_stage)
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")


# =============================================================================
#  EFEITOS VISUAIS
# =============================================================================

# --- Flash branco no inimigo (para bosses sem script) ---
func _flash_enemy(enemy: Node2D) -> void:
	var body = enemy.get_node_or_null("Body")
	if body and body is ColorRect:
		var original_color: Color = enemy.get_meta("original_color", body.color)
		body.color = Color(1, 1, 1, 1)
		var timer = get_tree().create_timer(0.15)
		var body_ref = body
		timer.timeout.connect(func():
			if is_instance_valid(body_ref):
				body_ref.color = original_color
		)


# --- Flash branco no jogador ao ser atingido ---
func _flash_player() -> void:
	var body = player.get_node_or_null("Body")
	if body and body is ColorRect:
		var original_color: Color = body.color
		body.color = Color(1, 1, 1, 1)
		var timer = get_tree().create_timer(0.15)
		var body_ref = body
		timer.timeout.connect(func():
			if is_instance_valid(body_ref):
				body_ref.color = original_color
		)


# =============================================================================
#  ATUALIZAÇÃO DA HUD
# =============================================================================

func _update_hud() -> void:
	var ammo = _get_current_ammo()
	if ammo_label:
		ammo_label.text = "x" + str(ammo_counts[current_ammo_index])
	if ammo_icon:
		ammo_icon.ammo_color = ammo.color
		ammo_icon.queue_redraw()
	if ammo_name_label:
		ammo_name_label.text = ammo.ammo_name


func _update_power_hud() -> void:
	if power_label:
		power_label.text = "Forca: " + str(round(current_power * 100)) + "%"


func _update_armor_hud() -> void:
	if armor_bar:
		armor_bar.value = Global.player_armor


func _update_stage_label() -> void:
	if stage_label:
		var base_id = Global.current_base_id if Global.current_base_id != "" else "?"
		var stage_num = Global.current_stage + 1  # Mostrar 1-indexed
		stage_label.text = "Base " + base_id + " - Fase " + str(stage_num) + "/3"


# =============================================================================
#  CALLBACKS DOS BOTÕES DA HUD (mantidos do original)
# =============================================================================

func _on_switch_ammo() -> void:
	current_ammo_index = (current_ammo_index + 1) % ammo_types.size()
	_update_hud()
	_update_aim_line()


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
	
	quit_btn = Button.new()
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
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.icon = load("res://assets/sprites/icons/exit.png")
	quit_btn.expand_icon = true
	quit_btn.add_theme_constant_override("icon_max_width", 24)
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
	
	armor_bar = ProgressBar.new()
	armor_bar.max_value = 100
	armor_bar.value = 100
	armor_bar.custom_minimum_size = Vector2(150, 20)
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	sb_bg.corner_radius_top_left = 5
	sb_bg.corner_radius_bottom_right = 5
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = Color(0.2, 0.6, 0.8, 1.0)
	sb_fg.corner_radius_top_left = 5
	sb_fg.corner_radius_bottom_right = 5
	armor_bar.add_theme_stylebox_override("background", sb_bg)
	armor_bar.add_theme_stylebox_override("fill", sb_fg)
	hp_vbox.add_child(armor_bar)
	
	# Stage Label
	stage_label = Label.new()
	stage_label.add_theme_font_override("font", font)
	stage_label.add_theme_font_size_override("font_size", 24)
	stage_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	stage_label.position = Vector2(950, 20)
	stage_label.size = Vector2(300, 40)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_canvas.add_child(stage_label)

	# Next Stage Btn
	next_stage_btn = Button.new()
	next_stage_btn.text = "-> Proxima Fase"
	next_stage_btn.add_theme_font_override("font", font)
	next_stage_btn.add_theme_font_size_override("font_size", 22)
	next_stage_btn.add_theme_stylebox_override("normal", normal_style)
	next_stage_btn.add_theme_stylebox_override("hover", hover_style)
	next_stage_btn.add_theme_stylebox_override("pressed", pressed_style)
	next_stage_btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.0))
	next_stage_btn.position = Vector2(1000, 330)
	next_stage_btn.size = Vector2(250, 50)
	next_stage_btn.visible = false
	next_stage_btn.pressed.connect(_on_next_stage)
	hud_canvas.add_child(next_stage_btn)

	# Return Btn (same style as quit btn)
	return_btn = Button.new()
	return_btn.text = "Voltar ao Mapa"
	return_btn.add_theme_font_override("font", font)
	return_btn.add_theme_font_size_override("font_size", 20)
	return_btn.add_theme_stylebox_override("normal", normal_style)
	return_btn.add_theme_stylebox_override("hover", hover_style)
	return_btn.add_theme_stylebox_override("pressed", pressed_style)
	return_btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.0))
	return_btn.icon = load("res://assets/sprites/icons/exit.png")
	return_btn.expand_icon = true
	return_btn.add_theme_constant_override("icon_max_width", 24)
	return_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return_btn.pressed.connect(_on_return_to_map)
	left_vbox.add_child(return_btn)
