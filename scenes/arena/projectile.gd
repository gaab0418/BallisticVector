extends Node2D

# === Propriedades configuradas pelo arena.gd ao instanciar ===
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 200.0
var precision: float = -0.75  # 0.0 = máximo desvio, 1.0 = sem desvio
var bullet_color: Color = Color(1.0, 0.85, 0.2, 1.0)  # Cor definida pelo AmmoData
var enemy_node: Node2D = null

# === Visual ===
var bullet_rect: ColorRect

# === Estado ===
var lifetime: float = 0.0
const MAX_LIFETIME: float = 8.0  # Segundos antes de autodestruir

func _ready() -> void:
	randomize()
	# Criar o visual do projétil (retângulo pequeno)
	bullet_rect = ColorRect.new()
	bullet_rect.size = Vector2(10, 6)
	bullet_rect.position = Vector2(-5, -3)  # Centralizar
	bullet_rect.color = bullet_color
	add_child(bullet_rect)

func _process(delta: float) -> void:
	lifetime += delta
	if lifetime > MAX_LIFETIME:
		queue_free()
		return
	
	# === Aplicar gravidade ===
	velocity.y += gravity * delta
	
	# === Mover o projétil ===
	position += velocity * delta
	
	# === Aplicar desvio aleatório na POSIÇÃO (tremor/wobble) ===
	# Quanto menor a precisão (pode ser negativo), maior o wobble
	var wobble_strength: float = (1.0 - precision) * 40.0
	position.x += randf_range(-wobble_strength, wobble_strength) * delta
	position.y += randf_range(-wobble_strength, wobble_strength) * delta
	
	# === Rotacionar o projétil na direção do movimento ===
	rotation = velocity.angle()
	
	# === Verificar se saiu da tela ===
	if position.x > 1350 or position.x < -50 or position.y > 780 or position.y < -60:
		queue_free()
		return
	
	# === Verificar colisão com o inimigo (simples, por distância) ===
	if enemy_node and is_instance_valid(enemy_node):
		var dist = position.distance_to(enemy_node.position)
		if dist < 35.0:  # Raio de colisão
			_on_hit_enemy()

func _on_hit_enemy() -> void:
	# Efeito visual simples: flash no inimigo
	if enemy_node and is_instance_valid(enemy_node):
		var body = enemy_node.get_node_or_null("Body")
		if body and body is ColorRect:
			# Flash branco
			var original_color = body.color
			body.color = Color(1, 1, 1, 1)
			# Criar um timer para restaurar a cor
			var timer = get_tree().create_timer(0.15)
			timer.timeout.connect(func():
				if is_instance_valid(body):
					body.color = original_color
			)
	print("Acertou o inimigo!")
	queue_free()
