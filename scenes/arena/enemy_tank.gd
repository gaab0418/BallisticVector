extends Node2D
## Tanque inimigo: anda de um lado para o outro numa faixa do chao e revida com
## tiros parabolicos -- os mesmos projeteis (projectile.gd) dos avioes.
##
## Segue o contrato dos avioes com a arena (hp, take_damage, on_enemy_destroyed),
## entao entra na lista de inimigos sem nada especial no resto do codigo.

const HULL_TEX := preload("res://assets/sprites/tank_hull.png")
const BARREL_TEX := preload("res://assets/sprites/tank_barrel.png")
const ProjectileScript := preload("res://scenes/arena/projectile.gd")

const SPEED := 40.0
const SHOT_GRAVITY := 300.0
const SHOT_SPEED := 340.0

var hp := 2
var zone := Vector2(900, 1100)
var player_ref: Node2D
var _dir := -1.0
var _timer := 3.0
var _body: Sprite2D
var _barrel_pivot: Node2D


func _ready() -> void:
	z_index = 1
	var rig := Node2D.new()
	rig.scale = Vector2(-0.18, 0.18)
	add_child(rig)
	_barrel_pivot = Node2D.new()
	_barrel_pivot.position = Vector2(404, 139) - Vector2(338, 184.5)
	_barrel_pivot.rotation = -0.5
	rig.add_child(_barrel_pivot)
	var barrel := Sprite2D.new()
	barrel.texture = BARREL_TEX
	barrel.centered = false
	barrel.offset = Vector2(10, -21)
	barrel.modulate = UiTokens.ENEMY_TANK_TINT
	_barrel_pivot.add_child(barrel)
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.texture = HULL_TEX
	_body.modulate = UiTokens.ENEMY_TANK_TINT
	rig.add_child(_body)
	_timer = randf_range(2.5, 4.5)


func _process(delta: float) -> void:
	position.x += _dir * SPEED * delta
	if position.x < zone.x:
		position.x = zone.x
		_dir = 1.0
	elif position.x > zone.y:
		position.x = zone.y
		_dir = -1.0
	# Esteira balancando um pixel enquanto anda.
	_body.position.y = 1.0 if int(position.x / 5.0) % 2 == 0 else 0.0
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(4.0, 6.0)
		_shoot()


## Mesma pontaria dos avioes: tempo de voo pela distancia e uma folga aleatoria.
func _shoot() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var arena := get_parent()
	var origin := global_position + Vector2(-30, -22)
	var target := player_ref.global_position + Vector2(randf_range(-120, 120), 0)
	var diff := target - origin
	var t := clampf(absf(diff.x) / SHOT_SPEED, 0.8, 3.0)
	var v := Vector2(diff.x / t, (diff.y - 0.5 * SHOT_GRAVITY * t * t) / t)
	var p = ProjectileScript.new()
	p.position = origin
	p.velocity = v * randf_range(0.92, 1.08)
	p.gravity = SHOT_GRAVITY
	p.bullet_color = UiTokens.ENEMY_SHOT
	p.damage = 8
	p.is_enemy_projectile = true
	p.player_node = player_ref
	if arena.has_method("get_obstacle_polygons"):
		p.obstacle_polygons = arena.get_obstacle_polygons()
	arena.add_child(p)
	ArenaFx.spawn(arena, origin, ArenaFx.Kind.MUZZLE, v.normalized())


func take_damage(_amount: int) -> void:
	hp -= 1
	ArenaFx.flash_sprite(_body)
	if hp <= 0:
		var arena := get_parent()
		if arena and arena.has_method("on_enemy_destroyed"):
			arena.on_enemy_destroyed(self)
		queue_free()
