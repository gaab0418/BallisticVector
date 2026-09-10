extends Node2D

# === Sprites da municao: o do jogador aponta pra direita (sai do tanque em
# direcao ao castelo), o do inimigo aponta pra esquerda (aviao atirando no
# tanque). A rotacao segue a velocidade, entao cada um precisa de um offset
# de "frente" diferente -- ver _sprite_forward_offset em _ready().
const BULLET_TEX_RIGHT := preload("res://assets/sprites/ammo/bullet_right.png")
const BULLET_TEX_LEFT := preload("res://assets/sprites/ammo/bullet_left.png")
const BULLET_TARGET_WIDTH: float = 26.0

# === Propriedades configuradas pelo arena.gd ao instanciar ===
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 200.0
var bullet_color: Color = Color(1.0, 0.85, 0.2, 1.0)  # Cor definida pelo AmmoData
var damage: int = 1  # Dano causado ao acertar

# === Alvos ===
var enemy_nodes: Array = []  # Lista de inimigos ativos (projétil do jogador)
var player_node: Node2D = null  # Referência ao jogador (projétil inimigo)
var is_enemy_projectile: bool = false  # true = projétil disparado por inimigo

# === Obstáculos ===
# Array de PackedVector2Array representando polígonos de obstáculos em coords globais
var obstacle_polygons: Array = []

# === Visual ===
var bullet_sprite: Sprite2D
# Angulo que soma-se a velocity.angle() pra a ponta do sprite acompanhar o
# voo: 0 pro sprite que ja aponta pra +X, PI pro que aponta pra -X.
var _sprite_forward_offset: float = 0.0

# === Estado ===
var lifetime: float = 0.0
const MAX_LIFETIME: float = 8.0  # Segundos antes de autodestruir
const HIT_RADIUS_ENEMY: float = 35.0  # Raio de colisão contra inimigos
const HIT_RADIUS_PLAYER: float = 40.0  # Raio de colisão contra jogador


func _ready() -> void:
	randomize()
	# Criar o visual do projétil: municao do jogador aponta pra direita,
	# municao do inimigo aponta pra esquerda -- ver comentario no topo do arquivo.
	bullet_sprite = Sprite2D.new()
	bullet_sprite.texture = BULLET_TEX_LEFT if is_enemy_projectile else BULLET_TEX_RIGHT
	bullet_sprite.modulate = bullet_color
	_sprite_forward_offset = PI if is_enemy_projectile else 0.0
	var tex_width: float = bullet_sprite.texture.get_width()
	var scale_factor: float = BULLET_TARGET_WIDTH / tex_width
	bullet_sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(bullet_sprite)


func _process(delta: float) -> void:
	lifetime += delta
	if lifetime > MAX_LIFETIME:
		queue_free()
		return

	# === Aplicar gravidade ===
	velocity.y += gravity * delta

	# === Mover o projétil ===
	position += velocity * delta

	# === Rotacionar o projétil na direção do movimento ===
	rotation = velocity.angle() - _sprite_forward_offset

	# === Verificar se saiu da tela ===
	if position.x > 1350 or position.x < -50 or position.y > 780 or position.y < -60:
		queue_free()
		return

	# === Verificar colisão com obstáculos ===
	if _check_obstacle_collision():
		_on_hit_obstacle()
		return

	# === Lógica de colisão depende do tipo de projétil ===
	if is_enemy_projectile:
		_check_player_collision()
	else:
		_check_enemy_collision()


# --- Verifica se o projétil colidiu com algum polígono de obstáculo ---
func _check_obstacle_collision() -> bool:
	for poly in obstacle_polygons:
		if poly is PackedVector2Array and poly.size() >= 3:
			if Geometry2D.is_point_in_polygon(position, poly):
				return true
	return false


# --- Verifica colisão com todos os inimigos da lista ---
func _check_enemy_collision() -> void:
	for enemy in enemy_nodes:
		if enemy and is_instance_valid(enemy):
			var dist = position.distance_to(enemy.global_position)

			# Define o raio padrão (35.0 para os aviões)
			var current_hit_radius: float = HIT_RADIUS_ENEMY

			# Se o inimigo for o Boss, aumenta o raio consideravelmente (ex: 150 pixels)
			if enemy.has_meta("is_boss") and enemy.get_meta("is_boss") == true:
				current_hit_radius = 85.0

			# Verifica a colisão com o raio correto
			if dist < current_hit_radius:
				_on_hit_enemy(enemy)
				return


# --- Verifica colisão com o jogador (projétil inimigo) ---
func _check_player_collision() -> void:
	if player_node and is_instance_valid(player_node):
		var dist = position.distance_to(player_node.global_position)
		if dist < HIT_RADIUS_PLAYER:
			_on_hit_player()


# --- Projétil do jogador acertou um inimigo ---
func _on_hit_enemy(enemy: Node2D) -> void:
	AudioManager.play_sfx("res://assets/audio/cannon_hit_cannon.ogg")
	# Delegar o tratamento de dano ao arena.gd (nó pai)
	var arena = get_parent()
	if arena and arena.has_method("on_enemy_hit"):
		arena.on_enemy_hit(enemy, damage)
	queue_free()


# --- Projétil inimigo acertou o jogador ---
func _on_hit_player() -> void:
	AudioManager.play_sfx("res://assets/audio/cannon_hit_cannon.ogg")
	# Delegar o tratamento de dano ao arena.gd (nó pai)
	var arena = get_parent()
	if arena and arena.has_method("on_player_hit"):
		arena.on_player_hit(damage)
	queue_free()


# --- Projétil atingiu um obstáculo (montanha) ---
func _on_hit_obstacle() -> void:
	# Simplesmente destruir o projétil ao colidir com obstáculo
	queue_free()
