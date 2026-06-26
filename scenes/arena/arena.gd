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

# === Referências HUD ===
@onready var ammo_label: Label = $HUD/LeftPanel/AmmoPanel/AmmoLabel
@onready var ammo_icon: ColorRect = $HUD/LeftPanel/AmmoPanel/AmmoIcon
@onready var ammo_name_label: Label = $HUD/LeftPanel/AmmoNameLabel
@onready var power_label: Label = $HUD/LeftPanel/PowerLabel
@onready var armor_bar: ProgressBar = $HUD/ArmorBar
@onready var stage_label: Label = $HUD/StageLabel
@onready var next_stage_btn: Button = $HUD/NextStageBtn
@onready var return_btn: Button = $HUD/ReturnBtn

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
		var airplane = _create_airplane(config.airplane_hp)
		airplane.position = Vector2(
			randf_range(750.0, 1200.0),
			randf_range(200.0, 480.0)
		)
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


# --- Cria um avião inimigo com o script airplane_enemy.gd ---
func _create_airplane(airplane_hp: int) -> Node2D:
	var airplane = Node2D.new()
	airplane.set_script(AirplaneScript)
	airplane.name = "Airplane"
	airplane.hp = airplane_hp
	airplane.player_ref = player
	# As propriedades visuais e de movimento são definidas no _ready do script
	return airplane


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

	ammo_counts[current_ammo_index] -= 1
	Global.ammo_inventory[ammo.ammo_name] = ammo_counts[current_ammo_index]
	_update_hud()

	# Criar o projétil como um ColorRect dentro de um Node2D
	var projectile = Node2D.new()
	projectile.set_script(ProjectileScript)

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
	active_enemies.erase(enemy)
	# Verificar se todos os inimigos morreram
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
	Global.money += 50

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
		ammo_icon.color = ammo.color
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
