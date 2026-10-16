class_name StageBuilder
extends RefCounted
## Monta o cenario de uma fase a partir de Campaign: montanhas (arredondadas),
## chao como obstaculo, castelo e avioes.
##
## Saiu de arena.gd, que passou do teto de 1000 linhas do .gdlintrc. A arena
## continua dona do estado do combate; aqui so nascem os nos.

const RockVisualScript = preload("res://scenes/arena/rock_visual.gd")
const HpPipsScript = preload("res://scenes/arena/hp_pips.gd")
const AirplaneScript = preload("res://scenes/arena/airplane_enemy.gd")
const BOSS_TEXTURE = preload("res://assets/sprites/boss.png")

## O sprite do castelo tem a base 86 px abaixo do centro (escala 0.5).
const BOSS_BASE_OFFSET: float = 86.0


## Montanhas e chao dentro de `parent`. A mesma curva arredondada serve de
## desenho e de colisao, entao o que se ve e o que a bala enxerga.
static func build_obstacles(
	parent: Node2D, stage: Dictionary, rock: Array, ground_poly: PackedVector2Array
) -> void:
	for data in stage.get("obstacles", []):
		var body := StaticBody2D.new()
		body.name = "Mountain"
		body.position = data.pos
		parent.add_child(body)
		var col := CollisionPolygon2D.new()
		col.name = "CollisionPolygon2D"
		col.polygon = Campaign.rounded(data.poly)
		body.add_child(col)
		var visual := Node2D.new()
		visual.name = "Visual"
		visual.set_script(RockVisualScript)
		body.add_child(visual)
		visual.setup(rock)

	# O chao tambem e obstaculo: a bala para nele, e a mira para junto. Fica por
	# ultimo na lista de proposito (ver arena._mountain_polygons).
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	parent.add_child(ground)
	var ground_col := CollisionPolygon2D.new()
	ground_col.name = "CollisionPolygon2D"
	ground_col.polygon = ground_poly
	ground.add_child(ground_col)


## Castelo apoiado no chao e avioes; devolve a lista de inimigos vivos.
static func spawn_enemies(arena: Node2D, stage: Dictionary, player: Node2D) -> Array:
	var enemies: Array = []
	var boss := _create_boss(3)
	boss.position = Vector2(stage.get("boss_x", 1100.0), Campaign.GROUND_Y + 4.0 - BOSS_BASE_OFFSET)
	arena.add_child(boss)
	enemies.append(boss)

	for i in range(int(stage.get("planes", 2))):
		var airplane = AirplaneScript.new()
		airplane.name = "Airplane"
		# Abaixo do painel do topo, para nenhum aviao nascer escondido atras dele.
		airplane.position = Vector2(randf_range(750.0, 1200.0), randf_range(180.0, 440.0))
		airplane.hp = int(stage.get("plane_hp", 1))
		airplane.player_ref = player
		arena.add_child(airplane)
		enemies.append(airplane)
		# Aviao de um tiro so nao precisa de marcador de vida.
		if airplane.hp > 1:
			_attach_pips(airplane, -36.0)
	return enemies


static func _create_boss(boss_hp: int) -> Node2D:
	var boss := Node2D.new()
	boss.name = "Boss"
	var body := Sprite2D.new()
	body.name = "Body"
	body.texture = BOSS_TEXTURE
	body.scale = Vector2(0.5, 0.5)
	boss.add_child(body)
	boss.set_meta("hp", boss_hp)
	boss.set_meta("max_hp", boss_hp)
	boss.set_meta("is_boss", true)
	_attach_pips(boss, -100.0)
	return boss


static func _attach_pips(host: Node2D, offset_y: float) -> void:
	var pips := Node2D.new()
	pips.set_script(HpPipsScript)
	pips.offset_y = offset_y
	host.add_child(pips)
