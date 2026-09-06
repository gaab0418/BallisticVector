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
var sprite: Sprite2D = null

const TEXTURE_A = preload("res://assets/sprites/airplane_enemy_01.png")
const TEXTURE_B = preload("res://assets/sprites/airplane_enemy_02.png")

# Alternador estático: garante alternância estrita entre avião 1 e 2
static var use_skin_a: bool = true

# --- Preload do script do projétil ---
const ProjectileScript = preload("res://scenes/arena/projectile.gd")


func _ready() -> void:
	randomize()

	# Criar e configurar o Sprite2D
	sprite = Sprite2D.new()
	sprite.name = "Body"

	# Alternar rigorosamente a skin entre A e B
	if use_skin_a:
		sprite.texture = TEXTURE_A
	else:
		sprite.texture = TEXTURE_B

	# Inverte a flag para o próximo avião que for instanciado
	use_skin_a = not use_skin_a

	# Escala fixa padrão solicitada
	sprite.scale = Vector2(0.2, 0.2)

	add_child(sprite)

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

	# Espelhar o sprite de acordo com a direção do movimento
	if sprite:
		sprite.flip_h = (move_dir < 0)

	# Checagem geométrica para não bater nas montanhas
	var arena = get_parent()
	if arena and arena.has_method("get_obstacle_polygons"):
		var polygons = arena.get_obstacle_polygons()
		var check_pos = global_position + Vector2(move_speed * move_dir * 0.5, 0)
		for poly in polygons:
			if poly is PackedVector2Array and poly.size() >= 3:
				var lower_point = check_pos + Vector2(0, 20)
				if (
					Geometry2D.is_point_in_polygon(check_pos, poly)
					or Geometry2D.is_point_in_polygon(lower_point, poly)
				):
					move_dir *= -1.0
					position.x += move_dir * 2.0
					break

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

	var target_pos = player_ref.global_position
	target_pos.x += randf_range(-200.0, 200.0)
	target_pos.y += randf_range(-150.0, 150.0)

	var diff = target_pos - global_position
	var dist = diff.length()
	if dist < 10.0:
		return

	var flight_time = dist / projectile_impulse
	flight_time = clamp(flight_time, 0.5, 3.0)

	var vx = diff.x / flight_time
	var vy = (diff.y - 0.5 * projectile_gravity * flight_time * flight_time) / flight_time

	vx *= randf_range(0.85, 1.15)
	vy *= randf_range(0.85, 1.15)

	var projectile = ProjectileScript.new()
	projectile.position = global_position
	projectile.velocity = Vector2(vx, vy)
	projectile.gravity = projectile_gravity
	projectile.precision = -0.3
	projectile.bullet_color = Color(1.0, 0.3, 0.1, 1.0)
	projectile.damage = 8
	projectile.is_enemy_projectile = true
	projectile.player_node = player_ref

	if arena.has_method("get_obstacle_polygons"):
		projectile.obstacle_polygons = arena.get_obstacle_polygons()

	arena.add_child(projectile)


# --- Receber dano ---
func take_damage(amount: int) -> void:
	hp -= amount
	_flash_white()
	if hp <= 0:
		var arena = get_parent()
		if arena and arena.has_method("on_enemy_destroyed"):
			arena.on_enemy_destroyed(self)
		queue_free()


# --- Efeito de flash branco ao ser atingido ---
func _flash_white() -> void:
	if sprite:
		sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)

		# Espera 0.15 segundos na mesma linha
		await get_tree().create_timer(0.15).timeout

		# Só devolve a cor se o sprite ainda existir (se ele não morreu)
		if is_instance_valid(sprite):
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
