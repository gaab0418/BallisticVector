class_name AimPreview
extends Node2D
## Mira da arena: simula a trajetória do tiro e mantém a linha que a desenha.
##
## Vive como filho do Cannon e copia a `position` da AimLine da cena, para herdar o ajuste
## manual de alinhamento com a boca do cano em vez de duplicá-lo.
##
## Já teve um leque de incerteza desenhado em volta da linha, removido em 2026-09-06: com
## a munição imprecisa ele chegava a cobrir um terço da tela, e as trajetórias extremas
## (corretas, mas a 12° da mira) liam como erro de desenho em vez de como incerteza. A
## incerteza continua comunicada, em número, pelo "± N m" no Alcance da HUD.

const SIM_DT: float = 0.02
const SIM_STEPS: int = 200
# Limites da simulação, em coordenadas globais. Iguais aos do projétil real.
const BOUND_RIGHT: float = 1300.0
const BOUND_LEFT: float = -50.0
const BOUND_BOTTOM: float = 740.0

var _aim_line: Line2D
var _cannon: Node2D
var _obstacles: Array = []


## `aim_line` é a Line2D que já existe na cena; o preview passa a mantê-la.
func setup(cannon: Node2D, aim_line: Line2D) -> void:
	_cannon = cannon
	_aim_line = aim_line
	position = aim_line.position


func set_obstacles(polygons: Array) -> void:
	_obstacles = polygons


## `angle` é a rotação global do cano, em radianos.
func update_preview(origin: Vector2, angle: float, speed: float, gravity: float) -> void:
	if _aim_line == null:
		return
	_aim_line.points = _to_local(_simulate(origin, angle, speed, gravity))


## Integração de Euler idêntica à do projétil real (projectile.gd), para a linha
## desenhada e o tiro descreverem a mesma curva.
func _simulate(origin: Vector2, angle: float, speed: float, gravity: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var vel: Vector2 = Vector2.RIGHT.rotated(angle) * speed
	var pos: Vector2 = origin
	points.append(pos)

	for _i in range(SIM_STEPS):
		vel.y += gravity * SIM_DT
		pos += vel * SIM_DT
		if pos.x > BOUND_RIGHT or pos.x < BOUND_LEFT or pos.y > BOUND_BOTTOM:
			break
		points.append(pos)
		if _hits_obstacle(pos):
			break
	return points


func _hits_obstacle(point: Vector2) -> bool:
	for poly in _obstacles:
		if Geometry2D.is_point_in_polygon(point, poly):
			return true
	return false


func _to_local(globals: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p in globals:
		out.append(_cannon.to_local(p))
	return out
