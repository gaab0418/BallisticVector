class_name StageBuilder
extends RefCounted
## Monta o cenario de uma fase a partir de Campaign: obstaculos, chao e
## inimigos. A arena continua dona do estado do combate; aqui so nascem os nos.

const RockVisualScript = preload("res://scenes/arena/rock_visual.gd")
const HpPipsScript = preload("res://scenes/arena/hp_pips.gd")
const AirplaneScript = preload("res://scenes/arena/airplane_enemy.gd")
const BalloonScript = preload("res://scenes/arena/balloon.gd")
const BunkerScript = preload("res://scenes/arena/bunker.gd")
const EnemyTankScript = preload("res://scenes/arena/enemy_tank.gd")
const CastleDamageScript = preload("res://scenes/arena/castle_damage.gd")
const BALLOON_COLORS := [UiTokens.BALLOON_A, UiTokens.BALLOON_B, UiTokens.BALLOON_C]
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

	# Plato do tanque (Ilha Invertida). Quinas chanfradas, sem spline: pontos tao
	# proximos com tangentes longas fariam a curva dar um laco (poligono invalido).
	var h: float = stage.get("tank_height", 0.0)
	if h > 0.0:
		var top := -(720.0 - Campaign.GROUND_Y) - Ballistics.to_px(h)
		var mesa := StaticBody2D.new()
		mesa.name = "Plateau"
		mesa.position = Vector2(90, 720)
		parent.add_child(mesa)
		var col := CollisionPolygon2D.new()
		col.name = "CollisionPolygon2D"
		col.polygon = PackedVector2Array(
			[
				Vector2(-150, 0),
				Vector2(-142, top + 16),
				Vector2(-128, top),
				Vector2(80, top),
				Vector2(100, top + 18),
				Vector2(114, 0),
			]
		)
		mesa.add_child(col)
		var visual := Node2D.new()
		visual.name = "Visual"
		visual.set_script(RockVisualScript)
		mesa.add_child(visual)
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


## Castelo apoiado no chao, avioes, baloes, bunkers e tanques inimigos;
## devolve a lista de inimigos vivos (todos precisam cair para vencer).
static func spawn_enemies(arena: Node2D, stage: Dictionary, player: Node2D) -> Array:
	var enemies: Array = []
	var boss_x: float = stage.get("boss_x", 1100.0)
	if boss_x >= 0.0:
		var boss := _create_boss(3)
		boss.position = Vector2(boss_x, Campaign.GROUND_Y + 4.0 - BOSS_BASE_OFFSET)
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

	var balloons: Array = stage.get("balloons", [])
	for i in range(balloons.size()):
		var spec: Vector2 = balloons[i]
		var b := Node2D.new()
		b.name = "Balloon"
		b.set_script(BalloonScript)
		b.height_m = spec.y
		b.ground_y = Campaign.GROUND_Y
		b.color = BALLOON_COLORS[i % BALLOON_COLORS.size()]
		b.position = Vector2(spec.x, Campaign.GROUND_Y - Ballistics.to_px(spec.y))
		arena.add_child(b)
		enemies.append(b)

	for x in stage.get("bunkers", []):
		var bunker := Node2D.new()
		bunker.name = "Bunker"
		bunker.set_script(BunkerScript)
		bunker.position = Vector2(x, Campaign.GROUND_Y - 14.0)
		arena.add_child(bunker)
		enemies.append(bunker)
		_attach_pips(bunker, -48.0)

	var tanks: Dictionary = stage.get("tanks", {})
	for i in range(int(tanks.get("count", 0))):
		var zone: Vector2 = tanks.zone
		var tank := Node2D.new()
		tank.name = "EnemyTank"
		tank.set_script(EnemyTankScript)
		tank.zone = zone
		tank.player_ref = player
		tank.position = Vector2(lerpf(zone.x, zone.y, randf()), Campaign.GROUND_Y - 22.0)
		arena.add_child(tank)
		enemies.append(tank)
		_attach_pips(tank, -46.0)
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
	var damage := Node2D.new()
	damage.set_script(CastleDamageScript)
	boss.add_child(damage)
	return boss


static func _attach_pips(host: Node2D, offset_y: float) -> void:
	var pips := Node2D.new()
	pips.set_script(HpPipsScript)
	pips.offset_y = offset_y
	host.add_child(pips)
