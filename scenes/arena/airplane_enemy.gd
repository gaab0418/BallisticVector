extends Node2D

# === Script do inimigo avião ===
# Movimenta-se horizontalmente e dispara projéteis parabólicos no jogador.

# --- Vida ---
var hp: int = 1

# --- Referências ---
var player_ref: Node2D = null  # Referência ao jogador

# --- Movimento ---
var move_speed: float = 60.0
var move_dir: float = 1.0  # 1.0 = direita, -1.0 = esquerda
var min_x: float = 600.0
var max_x: float = 1200.0

# --- Disparo ---
var shoot_timer: float = 0.0
var shoot_interval: float = 4.0  # Segundos entre cada tiro
var projectile_gravity: float = 300.0
var projectile_impulse: float = 350.0

# --- Visual ---
var body_rect: ColorRect = null
var original_color: Color = Color(0.85, 0.35, 0.15, 1.0)

# --- Preload do script do projétil ---
const ProjectileScript = preload("res://scenes/arena/projectile.gd")

func _ready() -> void:
	randomize()
	# Criar o visual do avião (retângulo colorido)
	body_rect = ColorRect.new()
	body_rect.name = "Body"
	body_rect.size = Vector2(40, 20)
	body_rect.position = Vector2(-20, -10)  # Centralizar
	body_rect.color = original_color
	add_child(body_rect)

	# Asa superior (detalhe visual)
	var wing = ColorRect.new()
	wing.size = Vector2(20, 6)
	wing.position = Vector2(-10, -16)
	wing.color = original_color.darkened(0.2)
	add_child(wing)

	# Intervalo de disparo com variação aleatória
	shoot_timer = randf_range(1.0, shoot_interval)
	# Direção inicial aleatória
	move_dir = [-1.0, 1.0].pick_random()

func _process(delta: float) -> void:
	# === Movimento horizontal ===
	position.x += move_speed * move_dir * delta

	# Inverter direção nas bordas
	if position.x >= max_x:
		position.x = max_x
		move_dir = -1.0
	elif position.x <= min_x:
		position.x = min_x
		move_dir = 1.0

	# === Timer de disparo ===
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval + randf_range(-0.5, 0.5)
		_shoot_at_player()


# --- Dispara um projétil parabólico na direção do jogador ---
func _shoot_at_player() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return

	var arena = get_parent()
	if not arena:
		return

	# Calcular direção e velocidade para atingir o jogador
	var target_pos = player_ref.global_position
	# Imprecisão grande — aviões NÃO acertam com facilidade
	target_pos.x += randf_range(-200.0, 200.0)
	target_pos.y += randf_range(-150.0, 150.0)

	var diff = target_pos - global_position
	var dist = diff.length()
	if dist < 10.0:
		return

	# Cálculo balístico simplificado:
	# Usamos o tempo estimado de voo para calcular a velocidade necessária
	var flight_time = dist / projectile_impulse
	flight_time = clamp(flight_time, 0.5, 3.0)

	# Velocidade horizontal necessária
	var vx = diff.x / flight_time
	# Velocidade vertical com compensação de gravidade
	var vy = (diff.y - 0.5 * projectile_gravity * flight_time * flight_time) / flight_time

	# Adicionar perturbação aleatória na velocidade final (±15%)
	vx *= randf_range(0.85, 1.15)
	vy *= randf_range(0.85, 1.15)

	# Criar o projétil
	var projectile = ProjectileScript.new()
	projectile.position = global_position
	projectile.velocity = Vector2(vx, vy)
	projectile.gravity = projectile_gravity
	projectile.precision = -0.3  # Precisão ruim = bastante wobble no voo
	projectile.bullet_color = Color(1.0, 0.3, 0.1, 1.0)  # Vermelho-laranja
	projectile.damage = 8
	projectile.is_enemy_projectile = true
	projectile.player_node = player_ref

	# Passar os polígonos de obstáculos (obtidos do arena)
	if arena.has_method("get_obstacle_polygons"):
		projectile.obstacle_polygons = arena.get_obstacle_polygons()

	arena.add_child(projectile)


# --- Receber dano ---
func take_damage(amount: int) -> void:
	hp -= amount
	_flash_white()
	if hp <= 0:
		# Notificar o arena antes de morrer
		var arena = get_parent()
		if arena and arena.has_method("on_enemy_destroyed"):
			arena.on_enemy_destroyed(self)
		queue_free()


# --- Efeito de flash branco ao ser atingido ---
func _flash_white() -> void:
	if body_rect:
		body_rect.color = Color(1, 1, 1, 1)
		# Restaurar cor após 0.15 segundos
		var timer = get_tree().create_timer(0.15)
		var rect_ref = body_rect
		var restore_color = original_color
		timer.timeout.connect(func():
			if is_instance_valid(rect_ref):
				rect_ref.color = restore_color
		)
