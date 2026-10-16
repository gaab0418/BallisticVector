extends Node2D
## O tiro decorativo do menu: uma bala que desenha a propria parabola no ceu do
## acampamento e marca o vertice quando passa por ele.
## Usa Ballistics, a mesma conta da arena.

signal finished

const SPEED_PX := 760.0
const GRAVITY_PX := 420.0
const DASH := 10.0
const GAP := 7.0

var _shot: Dictionary = {}
var _x := 0.0
var _x_end := 0.0
var _dir := -1.0
var _passed_vertex := false
var _fade := 1.0
var _ground_y := 650.0


## `dir` = -1 atira para a esquerda (o tanque do menu olha para a esquerda).
func fire(muzzle: Vector2, angle_deg: float, ground_y: float, dir: float) -> void:
	_dir = dir
	_ground_y = ground_y
	# A conta e feita "olhando para a direita" e espelhada ao desenhar.
	_shot = Ballistics.shot(angle_deg, SPEED_PX, GRAVITY_PX, Vector2(0, muzzle.y), 0.0, ground_y)
	position = Vector2(muzzle.x, 0)
	_x = 0.0
	_x_end = Ballistics.root(_shot)
	_passed_vertex = false
	_fade = 1.0
	visible = true


func _process(delta: float) -> void:
	if _shot.is_empty():
		return
	if _x < _x_end:
		_x = minf(_x + Ballistics.to_m(SPEED_PX * 0.55) * delta, _x_end)
		if not _passed_vertex and _x >= Ballistics.vertex(_shot).x:
			_passed_vertex = true
	else:
		_fade -= delta * 0.6
		if _fade <= 0.0:
			_shot = {}
			visible = false
			finished.emit()
	queue_redraw()


func _p(x: float) -> Vector2:
	var p := Ballistics.point_px(_shot, x)
	return Vector2(p.x * _dir, p.y)


func _draw() -> void:
	if _shot.is_empty():
		return
	var trail := Color(UiTokens.CALCULATED, 0.75 * _fade)
	var step := Ballistics.to_m(6.0)
	var x := 0.0
	var dist := 0.0
	var prev := _p(0.0)
	while x < _x:
		x = minf(x + step, _x)
		var p := _p(x)
		if fmod(dist, DASH + GAP) < DASH:
			draw_line(prev, p, trail, 3.0)
		dist += prev.distance_to(p)
		prev = p

	if _x < _x_end:
		# A bala: um retangulo de latao apontado no sentido do voo.
		var ahead := _p(minf(_x + step, _x_end))
		var ang := (ahead - prev).angle()
		draw_set_transform(prev, ang, Vector2.ONE)
		draw_rect(Rect2(-7, -3, 14, 6), UiTokens.BRASS)
		draw_rect(Rect2(3, -3, 4, 6), UiTokens.BRASS_LIGHT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _passed_vertex:
		var v := _p(Ballistics.vertex(_shot).x)
		var col := Color(UiTokens.CALCULATED, _fade)
		UiIcon.paint(self, "vertex", Rect2(v - Vector2(11, 11), Vector2(22, 22)), col)
