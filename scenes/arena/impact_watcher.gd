extends Node
## Observa a arena sem mexer na fisica: poeira onde a bala some ao bater no chao
## ou numa montanha, e a tremida de camera. O impacto e deduzido da ultima
## posicao de cada bala antes de sumir (projectile.gd nao avisa).

var arena: Node2D
var camera: Camera2D
var projectile_script: Script
var _tracked: Dictionary = {}
## id -> true para as balas do jogador (as que tem meta "shot").
var _player: Dictionary = {}

## Bala do jogador sumiu: onde, e se foi batendo em obstaculo/chao.
signal player_shot_ended(pos: Vector2, hit_obstacle: bool)
var _shake := 0.0


func setup(host: Node2D, cam: Camera2D, script: Script) -> void:
	arena = host
	camera = cam
	projectile_script = script


## Tremida de camera, em pixels.
func kick(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	_track()
	if _shake <= 0.05:
		camera.offset = Vector2.ZERO
		return
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = move_toward(_shake, 0.0, 30.0 * delta)


func _track() -> void:
	var alive := {}
	for child in arena.get_children():
		if child.get_script() == projectile_script and not child.is_queued_for_deletion():
			alive[child.get_instance_id()] = child.position
			if child.has_meta("shot"):
				_player[child.get_instance_id()] = true
	for id in _tracked:
		if not alive.has(id):
			var p: Vector2 = _tracked[id]
			var hit := p.y > Campaign.GROUND_Y - 6.0 or _inside_obstacle(p)
			if hit:
				ArenaFx.spawn(arena, p, ArenaFx.Kind.DUST)
			if _player.erase(id):
				player_shot_ended.emit(p, hit)
	_tracked = alive


func _inside_obstacle(p: Vector2) -> bool:
	for poly in arena.get_obstacle_polygons():
		if Geometry2D.is_point_in_polygon(p + Vector2(0, 6), poly):
			return true
	return false
