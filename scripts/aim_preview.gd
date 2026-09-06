class_name AimPreview
extends Node2D
## Mira da arena: a trajetória central mais o leque de incerteza em volta dela.
##
## O leque é a região que o tiro pode ocupar, dado o desvio máximo da munição e da
## armadura: um polígono translúcido com as duas trajetórias extremas como borda. Com a
## Perfurante ele quase some; com a Enferrujada ele abre — é a leitura visual de "esta
## arma é certeira" e "esta aqui é chute", sem precisar de texto.
##
## Vive como filho do Cannon e copia a `position` da AimLine da cena, para herdar o ajuste
## manual de alinhamento com a boca do cano em vez de duplicá-lo.

const SIM_DT: float = 0.02
const SIM_STEPS: int = 200
# Trajetórias amostradas para montar o leque. Ímpar de propósito: inclui a central.
# Cinco já fecham o envelope sem custo perceptível — são 5 x 200 passos por atualização.
const FAN_SAMPLES: int = 5
# Elevação de 45°, o ângulo de alcance máximo. Negativo porque em Godot 2D o eixo Y
# aponta para baixo, então rotação negativa é o cano apontado para cima.
const MAX_RANGE_ANGLE: float = -PI / 4.0
# Limites da simulação, em coordenadas globais. Iguais aos do projétil real.
const BOUND_RIGHT: float = 1300.0
const BOUND_LEFT: float = -50.0
const BOUND_BOTTOM: float = 740.0

const COLOR_FAN := Color(1.0, 0.35, 0.25, 0.13)
const COLOR_EDGE := Color(1.0, 0.45, 0.3, 0.35)
const EDGE_WIDTH: float = 1.0

var _fan: Polygon2D
var _edge_low: Line2D
var _edge_high: Line2D
var _aim_line: Line2D
var _cannon: Node2D
var _obstacles: Array = []


## `aim_line` é a Line2D central que já existe na cena; o preview passa a mantê-la.
func setup(cannon: Node2D, aim_line: Line2D) -> void:
	_cannon = cannon
	_aim_line = aim_line
	# Herda o alinhamento com a boca do cano ajustado à mão na cena.
	position = aim_line.position

	_fan = Polygon2D.new()
	_fan.color = COLOR_FAN
	# Atrás da linha central, senão o preenchimento lava a cor dela.
	_fan.z_index = -1
	add_child(_fan)

	_edge_low = _make_edge()
	_edge_high = _make_edge()


func set_obstacles(polygons: Array) -> void:
	_obstacles = polygons


## `angle` é a rotação global do cano em radianos, `spread` o desvio máximo para cada
## lado (também em radianos). spread == 0 esconde o leque.
func update_preview(
	origin: Vector2, angle: float, speed: float, gravity: float, spread: float
) -> void:
	if _aim_line == null:
		return

	_aim_line.points = _to_local(_simulate(origin, angle, speed, gravity))

	if spread <= 0.0:
		_set_fan_visible(false)
		return

	var low: PackedVector2Array = _simulate(origin, angle - spread, speed, gravity)
	var high: PackedVector2Array = _simulate(origin, angle + spread, speed, gravity)
	if low.size() < 2 or high.size() < 2:
		_set_fan_visible(false)
		return

	_set_fan_visible(true)
	_edge_low.points = _to_local(low)
	_edge_high.points = _to_local(high)
	_fan.polygon = _to_local(_envelope(origin, angle, speed, gravity, spread))


## O envelope da família de trajetórias, e não apenas a área entre as duas extremas.
##
## A diferença importa: o alcance não é monotônico no ângulo — ele é máximo em 45°. Se o
## intervalo (angle ± spread) contém 45°, uma trajetória do MEIO do leque vai mais longe
## que as duas bordas, e um polígono traçado só pelas bordas deixaria tiros reais do lado
## de fora. Como o ponto desta issue é a mira parar de mentir, o leque é montado
## amostrando ângulos e tomando, a cada passo de tempo, o ponto mais alto e o mais baixo.
func _envelope(
	origin: Vector2, angle: float, speed: float, gravity: float, spread: float
) -> PackedVector2Array:
	var angles: Array = []
	for i in range(FAN_SAMPLES):
		var t: float = float(i) / float(FAN_SAMPLES - 1)
		angles.append(angle - spread + 2.0 * spread * t)
	# Quando 45° cai dentro do leque, a trajetória mais longa é ELA, e não uma das bordas.
	# Sem esta amostra o polígono deixa de fora os tiros que vão mais longe — medido: até
	# 16 px de alcance descoberto, o suficiente para a bala cair visivelmente fora da faixa.
	if angle - spread < MAX_RANGE_ANGLE and MAX_RANGE_ANGLE < angle + spread:
		angles.append(MAX_RANGE_ANGLE)

	var trajectories: Array = []
	var longest: int = 0
	for sample_angle in angles:
		var sampled: PackedVector2Array = _simulate(origin, sample_angle, speed, gravity)
		trajectories.append(sampled)
		longest = maxi(longest, sampled.size())

	var upper: PackedVector2Array = PackedVector2Array()
	var lower: PackedVector2Array = PackedVector2Array()
	for step in range(longest):
		var top: Vector2 = Vector2.ZERO
		var bottom: Vector2 = Vector2.ZERO
		var found: bool = false
		for traj in trajectories:
			if step >= traj.size():
				continue
			var p: Vector2 = traj[step]
			if not found:
				top = p
				bottom = p
				found = true
				continue
			# Y cresce para baixo: menor y é o topo do leque.
			if p.y < top.y:
				top = p
			if p.y > bottom.y:
				bottom = p
		if found:
			upper.append(top)
			lower.append(bottom)

	lower.reverse()
	upper.append_array(lower)
	return upper


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


func _set_fan_visible(on: bool) -> void:
	_fan.visible = on
	_edge_low.visible = on
	_edge_high.visible = on


func _make_edge() -> Line2D:
	var line := Line2D.new()
	line.width = EDGE_WIDTH
	line.default_color = COLOR_EDGE
	line.z_index = -1
	add_child(line)
	return line
