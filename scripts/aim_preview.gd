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
# Colunas em x usadas para montar o polígono do leque.
const ENVELOPE_COLUMNS: int = 48
# Limites da simulação, em coordenadas globais. Iguais aos do projétil real.
const BOUND_RIGHT: float = 1300.0
const BOUND_LEFT: float = -50.0
const BOUND_BOTTOM: float = 740.0

# O leque varia de ~2.000 px² (Perfurante fraca) a ~334.000 px² (Enferrujada no
# talo, com a armadura zerada) — mais de um terço da tela. Com alpha fixo, ou o
# leque pequeno some ou o grande vira uma mancha que engole o cenário. O alpha então
# é inversamente proporcional à área, o que mantém a "quantidade de tinta" na tela
# aproximadamente constante: o leque grande fica sutil e o pequeno continua legível.
const FAN_INK: float = 25000.0
const FAN_ALPHA_MIN: float = 0.05
const FAN_ALPHA_MAX: float = 0.26
const COLOR_FAN := Color(1.0, 0.35, 0.25, 0.26)
const COLOR_EDGE := Color(1.0, 0.5, 0.35, 0.65)
const EDGE_WIDTH: float = 1.5

var _fan: Polygon2D
var _edge_low: Line2D
var _edge_high: Line2D
var _aim_line: Line2D
var _cannon: Node2D
var _obstacles: Array = []
var _fan_area: float = 0.0


## `aim_line` é a Line2D central que já existe na cena; o preview passa a mantê-la.
func setup(cannon: Node2D, aim_line: Line2D) -> void:
	_cannon = cannon
	_aim_line = aim_line
	# Herda o alinhamento com a boca do cano ajustado à mão na cena.
	position = aim_line.position
	# O leque fica atrás da linha central por ORDEM DE IRMÃOS, não por z_index: um
	# z_index negativo mandaria o leque para trás do fundo da arena, e ele sumiria.
	if get_parent() == cannon:
		cannon.move_child(self, 0)

	_fan = Polygon2D.new()
	_fan.color = COLOR_FAN
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
	var alpha: float = FAN_ALPHA_MAX
	if _fan_area > 0.0:
		alpha = clampf(FAN_INK / _fan_area, FAN_ALPHA_MIN, FAN_ALPHA_MAX)
	_fan.color = Color(COLOR_FAN.r, COLOR_FAN.g, COLOR_FAN.b, alpha)


## O envelope da família de trajetórias, montado COLUNA A COLUNA EM X.
##
## Duas armadilhas resolvidas aqui:
##
## 1. O alcance não é monotônico no ângulo — é máximo em 45°. Se o intervalo do desvio
##    contém 45°, a trajetória mais longa é uma do MEIO do leque, e um polígono traçado
##    só pelas bordas deixaria tiros reais de fora. Por isso amostramos vários ângulos,
##    mais o próprio ângulo de alcance máximo quando ele cai dentro.
##
## 2. Agrupar por passo de TEMPO produz um polígono auto-intersectante: no mesmo
##    instante, o ponto mais alto e o mais baixo do leque estão em posições x bem
##    diferentes, e o contorno cruza a si mesmo. O Polygon2D triangula por ear clipping
##    e falha nesses casos — o leque pisca e some justamente quando o cano sobe e as
##    trajetórias divergem. Agrupando por x o contorno é sempre simples, porque vx > 0
##    em todo o arco (o cano é limitado a ±70°) e portanto y(x) é função.
func _envelope(
	origin: Vector2, angle: float, speed: float, gravity: float, spread: float
) -> PackedVector2Array:
	var angles: Array = []
	for i in range(FAN_SAMPLES):
		var t: float = float(i) / float(FAN_SAMPLES - 1)
		angles.append(angle - spread + 2.0 * spread * t)
	if angle - spread < MAX_RANGE_ANGLE and MAX_RANGE_ANGLE < angle + spread:
		angles.append(MAX_RANGE_ANGLE)

	var trajectories: Array = []
	var x_end: float = origin.x
	for sample_angle in angles:
		var traj: PackedVector2Array = _simulate(origin, sample_angle, speed, gravity)
		if traj.size() < 2:
			continue
		trajectories.append(traj)
		x_end = maxf(x_end, traj[traj.size() - 1].x)

	if trajectories.is_empty() or x_end - origin.x < 1.0:
		return PackedVector2Array()

	var upper: PackedVector2Array = PackedVector2Array()
	var lower: PackedVector2Array = PackedVector2Array()
	var column_width: float = (x_end - origin.x) / float(ENVELOPE_COLUMNS)
	_fan_area = 0.0
	# Um cursor por trajetória: as colunas avançam em x e os pontos também, então a
	# varredura inteira é linear em vez de uma busca por coluna.
	var cursors: Array = []
	cursors.resize(trajectories.size())
	cursors.fill(0)

	for column in range(ENVELOPE_COLUMNS + 1):
		var ratio: float = float(column) / float(ENVELOPE_COLUMNS)
		var x: float = origin.x + (x_end - origin.x) * ratio
		var top: float = INF
		var bottom: float = -INF
		for i in range(trajectories.size()):
			var y: float = _height_at(trajectories[i], x, cursors, i)
			if is_inf(y):
				continue
			top = minf(top, y)
			bottom = maxf(bottom, y)
		if is_inf(top):
			break
		upper.append(Vector2(x, top))
		lower.append(Vector2(x, bottom))
		_fan_area += (bottom - top) * column_width

	if upper.size() < 2:
		return PackedVector2Array()

	lower.reverse()
	# As duas pontas do leque são um ponto só — na origem todas as trajetórias coincidem,
	# e na última coluna só a mais longa ainda existe. Sem esta checagem o vértice entraria
	# duplicado e o ear clipping do Polygon2D teria que lidar com um triângulo degenerado.
	var last: int = lower.size() - 1
	for i in range(lower.size()):
		var point: Vector2 = lower[i]
		if i == 0 and point.is_equal_approx(upper[upper.size() - 1]):
			continue
		if i == last and point.is_equal_approx(upper[0]):
			continue
		upper.append(point)
	return upper


## Altura da trajetória em um x, por interpolação linear entre os dois pontos que o
## cercam. Devolve INF quando o x está fora do trecho que esta trajetória percorreu.
func _height_at(traj: PackedVector2Array, x: float, cursors: Array, index: int) -> float:
	var i: int = cursors[index]
	while i + 1 < traj.size() and traj[i + 1].x < x:
		i += 1
	cursors[index] = i

	if i + 1 >= traj.size():
		# Passou do fim: só vale se for o próprio último ponto, a menos de um pixel.
		var last: Vector2 = traj[traj.size() - 1]
		return last.y if absf(last.x - x) <= 1.0 else INF

	var a: Vector2 = traj[i]
	var b: Vector2 = traj[i + 1]
	var span: float = b.x - a.x
	if absf(span) < 0.0001:
		return a.y
	return a.y + (b.y - a.y) * clampf((x - a.x) / span, 0.0, 1.0)


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
	add_child(line)
	return line
