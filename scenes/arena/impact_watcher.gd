extends Node
## Efeitos que observam a arena sem mexer na fisica: poeira onde a bala some ao
## bater no chao ou numa montanha, e a tremida de camera dos impactos.
##
## Saiu de arena.gd (teto de 1000 linhas do .gdlintrc). projectile.gd continua
## intocado: o impacto e deduzido da ultima posicao de cada bala antes de sumir.

var arena: Node2D
var camera: Camera2D
var projectile_script: Script
var _tracked: Dictionary = {}
var _shake := 0.0


func setup(host: Node2D, cam: Camera2D, script: Script) -> void:
	arena = host
	camera = cam
	projectile_script = script


## Tremida de camera, em pixels. Curta e pequena: so a sensacao do impacto.
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
	for id in _tracked:
		if not alive.has(id):
			var p: Vector2 = _tracked[id]
			if p.y > Campaign.GROUND_Y - 6.0 or _inside_obstacle(p):
				ArenaFx.spawn(arena, p, ArenaFx.Kind.DUST)
	_tracked = alive


func _inside_obstacle(p: Vector2) -> bool:
	for poly in arena.get_obstacle_polygons():
		if Geometry2D.is_point_in_polygon(p + Vector2(0, 6), poly):
			return true
	return false
