extends Node2D

# === Referências dos nós ===
@onready var player: Node2D = $Player
@onready var cannon: Node2D = $Player/Cannon
@onready var aim_line: Line2D = $Player/Cannon/AimLine
@onready var enemy: Node2D = $Enemy
@onready var bg: ColorRect = $BackgroundColorRect
@onready var ammo_label: Label = $HUD/LeftPanel/AmmoPanel/AmmoLabel
@onready var ammo_icon: ColorRect = $HUD/LeftPanel/AmmoPanel/AmmoIcon
@onready var ammo_name_label: Label = $HUD/LeftPanel/AmmoNameLabel

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

# === Preload do script do projétil ===
const ProjectileScript = preload("res://scenes/arena/projectile.gd")

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
	
	# Carregar munições dos Resources
	_load_ammo_types()
	_update_hud()
	_update_aim_line()

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
	var sim_vel: Vector2 = fire_direction * ammo.impulse
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
	projectile.velocity = fire_direction * ammo.impulse
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
	if ammo_icon:
		ammo_icon.color = ammo.color
	if ammo_name_label:
		ammo_name_label.text = ammo.ammo_name

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

func _on_quit() -> void:
	get_tree().change_scene_to_file("res://scenes/war_map/war_map.tscn")
