extends Node2D
## A parabola desenhada no mundo, com os pontos que a HUD descreve em numeros.
## A curva e a equacao de Ballistics, a mesma que a HUD escreve: o alcance do
## painel e a bandeira da raiz sao, por construcao, o mesmo numero.
##
## Linguagem visual, ligada por cor e forma ao painel:
##   cor "aim"  -- tudo que e calculado (curva, vertice, raiz, faixa). Vem do
##                 mundo: vermelho-alaranjado na Terra, azul onde o ceu e laranja
##                 ou escuro. O painel usa a mesma cor.
##   losango    -- vertice, com a altura maxima (ou minima, se a > 0) ao lado
##   bandeira   -- raiz (onde a bala toca o chao), com o alcance
##   X carmim   -- onde a bala bate antes de chegar la
##   arco ambar -- o angulo do cano, a unica coisa aqui que o jogador muda
##   linha y=h  -- (Base Echo) uma altura fixa; os cruzamentos da curva com ela
##                 sao as solucoes de ax² + bx + c = h, e o delta diz quantas ha
##   rota       -- (Foxtrot) a reta y = mx + n dos drones; cada cruzamento ganha
##                 um anel na rota: quando o drone passar ali, atire
##   quique     -- (Norte) a parabola depois do quique, mais fina
##   zona verde -- (Norte) o intervalo de pouso no chao
##
## Rotulos procuram um lugar livre: se o lugar preferido encosta na curva ou
## numa area da HUD, tentam o proximo.

const STEP_PX := 5.0
const DASH := 12.0
const GAP := 7.0
const MARCH_SPEED := 40.0
const MARKER := 22.0
const RIGHT_EDGE := 1280.0
## Encontros com a rota mais perto do canhao que isto nao ganham anel.
const MIN_INTERCEPT_M := 3.0

var shot: Dictionary = {}
var pivot := Vector2.ZERO
var band := Vector2(1, 0)
var obstacles: Array = []
## Retangulos de tela que tapam o mundo (paineis da HUD): marcador escondido
## ali vira seta na borda; rotulo nao e colocado em cima deles.
var occluders: Array = []
## Devolve os retangulos atuais da HUD a cada quadro: o layout dela so fica
## pronto depois do primeiro quadro, e uma lista fixa ficaria desatualizada.
var occluder_source: Callable
var show_cannon_height := false
## Altura (m) da linha y = h da Base Echo; NAN = sem linha.
var height_line := NAN
## Cor do que e calculado neste mundo (UiTokens.WORLD_*.aim).
var aim: Color = UiTokens.WORLD_EARTH.aim
## Rota dos drones: Vector2(m, n) da reta y = m x + n (NAN = sem rota).
var route := Vector2(NAN, NAN)
## Velocidade horizontal dos drones (px/s), para calcular quando atirar.
var route_speed := 46.0
## Intervalo de pouso (m) no chao; x > y = sem zona.
var land_zone := Vector2(1, 0)
## Fracao da velocidade vertical que sobra no quique (0 = sem quique).
var bounce_e := 0.0
## Modo chute: a curva some (so o angulo e a linha/rota/zona da fase ficam) e
## o palpite da crianca aparece no chao.
var guess_mode := false
var guess_x := NAN
## Mostra o texto "a bala pode cair aqui" (a Ada desliga depois de alguns segundos).
var band_label := true

var _font: Font
var _time := 0.0
var _points := PackedVector2Array()
var _hit_index := -1
var _bounce_points := PackedVector2Array()
var _bounce_shot: Dictionary = {}
## Retangulos ja ocupados por rotulos neste quadro.
var _taken: Array = []


func _ready() -> void:
	_font = UiTheme.body_font(UiTokens.WEIGHT_BOLD)


func update_shot(s: Dictionary, from: Vector2, landing: Vector2) -> void:
	shot = s
	pivot = from
	band = landing
	_rebuild()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Amostra a curva do munhao ate a raiz (ou ate sair da tela), e acha o
## primeiro ponto dentro de um obstaculo: dali em diante a curva vira "fantasma".
func _rebuild() -> void:
	_points.clear()
	_hit_index = -1
	if shot.is_empty():
		return
	var x0: float = shot.x_tank
	var origin_x: float = shot.origin_x_px
	var x_end := Ballistics.to_m(RIGHT_EDGE + 40.0 - origin_x)
	var r := Ballistics.root(shot)
	if not is_nan(r):
		x_end = minf(x_end, r)
	var step := Ballistics.to_m(STEP_PX)
	var x := x0
	while x <= x_end + step:
		var p := Ballistics.point_px(shot, minf(x, x_end))
		if p.y < -60.0 and x > x0:
			# Saiu por cima da tela. Com a < 0 ainda volta; com a > 0, nunca mais.
			if Ballistics.opens_up(shot):
				break
			x += step
			continue
		_points.append(p)
		if _hit_index < 0 and _points.size() > 2 and _inside_obstacle(p):
			_hit_index = _points.size() - 1
		x += step
	_rebuild_bounce()


## A parabola do quique: comeca na raiz, com o mesmo "a" e saida mais baixa.
func _rebuild_bounce() -> void:
	_bounce_points.clear()
	_bounce_shot = {}
	if bounce_e <= 0.0 or _hit_index >= 0 or not Ballistics.has_root(shot):
		return
	_bounce_shot = Ballistics.bounce(shot, bounce_e)
	if _bounce_shot.is_empty():
		return
	var x0: float = _bounce_shot.x_tank
	var x_end := Ballistics.to_m(RIGHT_EDGE + 40.0 - shot.origin_x_px)
	var r2 := Ballistics.root(_bounce_shot)
	if not is_nan(r2):
		x_end = minf(x_end, r2)
	var step := Ballistics.to_m(STEP_PX)
	var x := x0
	while x <= x_end + step:
		var p := Ballistics.point_px(_bounce_shot, minf(x, x_end))
		_bounce_points.append(p)
		if _bounce_points.size() > 2 and _inside_obstacle(p):
			break
		x += step


## Retangulo (tela) que envolve a curva desenhada: o holofote do tutorial.
func curve_rect() -> Rect2:
	if _points.is_empty():
		return Rect2(pivot, Vector2(10, 10))
	var r := Rect2(_points[0], Vector2.ZERO)
	for p in _points:
		r = r.expand(p)
	return r.grow(10.0)


func _inside_obstacle(p: Vector2) -> bool:
	for poly in obstacles:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func _draw() -> void:
	if occluder_source.is_valid():
		occluders = occluder_source.call()
	_taken = occluders.duplicate()
	if shot.is_empty() or _points.size() < 2:
		return
	if not is_nan(height_line):
		_draw_height_line()
	if land_zone.y > land_zone.x:
		_draw_land_zone()
	if not is_nan(route.x):
		_draw_route()
	if guess_mode:
		_draw_angle_arc()
		_draw_guess()
		return
	_draw_band()
	_draw_angle_arc()
	if show_cannon_height:
		_draw_cannon_height()

	var solid_end := _hit_index if _hit_index > 0 else _points.size() - 1
	var solid := _points.slice(0, solid_end + 1)
	var ghost := _points.slice(solid_end, _points.size())

	draw_polyline(solid, UiTokens.AIM_OUTLINE, 7.0)
	_dashed(solid, aim, 3.0, _time * MARCH_SPEED)
	if ghost.size() > 1:
		_dashed(ghost, Color(aim, UiTokens.AIM_GHOST_ALPHA), 2.0, 0.0)

	if _bounce_points.size() > 1:
		_dashed(_bounce_points, Color(aim, 0.75), 2.0, _time * MARCH_SPEED)
		_draw_bounce_root()
	_draw_vertex()
	_draw_root()
	if not is_nan(height_line):
		_draw_crossings()
	if not is_nan(route.x):
		_draw_route_crossings()
	if _hit_index > 0:
		var hp := _points[_hit_index]
		UiIcon.paint(self, "cross", Rect2(hp - Vector2(9, 9), Vector2(18, 18)), UiTokens.DANGER)
		_place_label(
			[hp + Vector2(-30, 28), hp + Vector2(14, -12)],
			"bate aqui",
			UiTokens.DANGER,
			UiTokens.FONT_XS
		)


## Tracejado que anda ao longo da curva, indicando o sentido do tiro.
func _dashed(pts: PackedVector2Array, col: Color, width: float, offset: float) -> void:
	var period := DASH + GAP
	var phase := fposmod(-offset, period)
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var t := 0.0
		while t < seg:
			var in_dash := phase < DASH
			var run := minf((DASH - phase) if in_dash else (period - phase), seg - t)
			if in_dash:
				draw_line(a.lerp(b, t / seg), a.lerp(b, (t + run) / seg), col, width)
			t += run
			phase = fposmod(phase + run, period)


func _draw_vertex() -> void:
	var up := Ballistics.opens_up(shot)
	if not Ballistics.has_arc(shot):
		# Sem vertice a frente: no lugar do numero, o que fazer.
		var tip := (
			"Abaixe o canhão: aqui a parábola abre para cima!"
			if up
			else "Levante o canhão para formar a parábola!"
		)
		var icon_rect := Rect2(pivot + Vector2(-80, -86), Vector2(16, 16))
		UiIcon.paint(self, "arrow_up", icon_rect, UiTokens.EDITABLE)
		_label(pivot + Vector2(-60, -70), tip, UiTokens.EDITABLE, UiTokens.FONT_SM)
		return
	var v := Ballistics.vertex(shot)
	var p := Ballistics.point_px(shot, v.x)
	var ground: float = shot.ground_y_px
	var text := ("Altura mín. " if up else "Altura máx. ") + Ballistics.fmt(v.y) + " m"

	var hidden := _hidden_rect(p)
	if hidden != Rect2() or p.y < 0.0:
		# Fora de vista: seta para cima na borda de baixo do que tapa.
		var y := (hidden.end.y if hidden != Rect2() else 0.0) + 8.0
		var at := Vector2(p.x, y)
		UiIcon.paint(self, "arrow_up", Rect2(at - Vector2(9, 0), Vector2(18, 18)), aim)
		_label(at + Vector2(14, 14), text, aim, UiTokens.FONT_SM)
		return

	# Linha de prumo do vertice ate o chao: a "altura" que o numero mede.
	_dashed(PackedVector2Array([p, Vector2(p.x, ground)]), Color(aim, 0.45), 2.0, 0.0)
	var m := Vector2(MARKER, MARKER)
	UiIcon.paint(self, "vertex", Rect2(p - m * 0.5, m), aim)
	_place_label(
		[
			p + Vector2(MARKER * 0.6, -MARKER * 0.5),
			p + Vector2(MARKER * 0.6, MARKER + 6),
			p + Vector2(-180, -MARKER * 0.5),
		],
		text,
		aim,
		UiTokens.FONT_SM
	)


func _draw_root() -> void:
	var r := Ballistics.root(shot)
	if is_nan(r):
		return
	var x: float = shot.origin_x_px + Ballistics.to_px(r)
	var ground: float = shot.ground_y_px
	var text := "Alcance " + Ballistics.fmt(r) + " m"
	if x > RIGHT_EDGE - 10.0:
		var at := Vector2(RIGHT_EDGE - 30.0, ground - 40.0)
		UiIcon.paint(self, "arrow_right", Rect2(at, Vector2(20, 20)), aim)
		_label(at + Vector2(-8, -4), text, aim, UiTokens.FONT_SM, true)
		return
	var flag := Rect2(Vector2(x - 6, ground - 30), Vector2(28, 28))
	UiIcon.paint(self, "root", flag, aim)
	_place_label(
		[Vector2(x + 18, ground - 34), Vector2(x + 18, ground - 60), Vector2(x - 150, ground - 60)],
		text,
		aim,
		UiTokens.FONT_SM
	)


## A faixa onde a bala pode cair (desvio da mira), desenhada sobre a regua.
func _draw_band() -> void:
	if band.y - band.x < 0.05:
		return
	var ground: float = shot.ground_y_px
	var x0: float = shot.origin_x_px + Ballistics.to_px(band.x)
	var x1 := minf(x0 + Ballistics.to_px(band.y - band.x), RIGHT_EDGE)
	if x1 <= x0:
		return
	var px := float(UiTokens.PX)
	draw_rect(Rect2(x0, ground - 4, x1 - x0, 30), Color(aim, UiTokens.BAND_ALPHA))
	for edge in [x0, x1]:
		draw_rect(Rect2(edge - px, ground - 10, px * 2, 36), Color(aim, 0.7))
	if band_label and x1 - x0 > 110.0:
		var mid := (x0 + x1) * 0.5 - 80.0
		_place_label(
			[
				Vector2(x0 + 6, ground - 12),
				Vector2(x0 + 6, ground + 48),
				Vector2(mid, ground - 40),
				Vector2(x0 + 6, ground - 40),
			],
			"a bala pode cair aqui",
			Color(aim, 0.95),
			UiTokens.FONT_XS
		)


## A linha y = h atravessando a tela, com o valor na ponta esquerda.
func _draw_height_line() -> void:
	var ground: float = shot.ground_y_px
	var y := ground - Ballistics.to_px(height_line)
	var x := 0.0
	var col := Color(UiTokens.EDITABLE, 0.55)
	while x < RIGHT_EDGE:
		draw_line(Vector2(x, y), Vector2(minf(x + 14.0, RIGHT_EDGE), y), col, 2.0)
		x += 24.0
	var label := "y = " + Ballistics.fmt(height_line, 0) + " m"
	_label(Vector2(8, y - 8), label, UiTokens.EDITABLE, UiTokens.FONT_SM)


## Cruzamentos da curva com a linha y = h: as solucoes da equacao. O texto diz
## quantas sao e o que o delta significa, em linguagem de crianca.
func _draw_crossings() -> void:
	var d := Ballistics.delta_at(shot, height_line)
	var xs := Ballistics.crossings(shot, height_line)
	var ground: float = shot.ground_y_px
	var y := ground - Ballistics.to_px(height_line)
	for xm in xs:
		var px: float = shot.origin_x_px + Ballistics.to_px(xm)
		draw_circle(Vector2(px, y), 9.0, UiTokens.AIM_OUTLINE, true, -1.0, false)
		draw_circle(Vector2(px, y), 6.0, UiTokens.EDITABLE, true, -1.0, false)
	var h := Ballistics.fmt(height_line, 0)
	var touching := absf(d) < 0.02 * maxf(1.0, shot.b * shot.b)
	var msg := ""
	if touching:
		msg = "Δ = 0: 1 solução — o vértice encosta em y = %s!" % h
	elif d > 0.0 and xs.size() == 2:
		msg = "Δ > 0: 2 soluções — a bala passa por %s m subindo e descendo" % h
	elif d > 0.0:
		msg = "Δ > 0: 2 soluções, mas só uma à frente do canhão"
	else:
		msg = "Δ < 0: nenhuma solução — a bala não chega a %s m" % h
	_place_label([Vector2(8, y - 34), Vector2(8, y + 26)], msg, UiTokens.EDITABLE, UiTokens.FONT_SM)


## Ponto da rota dos drones no x de tela `x_px`.
func _route_point(x_px: float) -> Vector2:
	var xm := Ballistics.to_m(x_px - shot.origin_x_px)
	return Vector2(x_px, shot.ground_y_px - Ballistics.to_px(route.x * xm + route.y))


func _draw_route() -> void:
	var col := Color(UiTokens.DRONE_ROUTE, 0.6)
	var x := pivot.x
	while x < RIGHT_EDGE:
		draw_line(_route_point(x), _route_point(minf(x + 14.0, RIGHT_EDGE)), col, 2.0)
		x += 24.0
	var eq := (
		"rota: y = "
		+ Ballistics.term(route.x, 2, "x", true)
		+ " "
		+ Ballistics.term(route.y, 1, "")
	)
	# Do lado de onde os drones chegam, longe do tanque e do arco do angulo.
	var candidates := []
	for x_px in [880.0, 640.0, 420.0]:
		var p := _route_point(x_px)
		candidates.append(p + Vector2(0, 30))
		candidates.append(p + Vector2(0, -14))
	_place_label(candidates, eq, UiTokens.DRONE_ROUTE, UiTokens.FONT_SM)


## Encontros da curva com a rota (as solucoes de ax² + bx + c = mx + n) e, para
## cada um, o anel na rota: o drone precisa estar ali quando a bala sair, porque
## ele anda enquanto ela voa.
func _draw_route_crossings() -> void:
	var xs := Ballistics.crossings_line(shot, route.x, route.y)
	var r := Ballistics.root(shot)
	var labeled := false
	for i in range(xs.size()):
		var xm: float = xs[i]
		if not is_nan(r) and xm > r:
			continue
		var cp := _route_point(shot.origin_x_px + Ballistics.to_px(xm))
		if _hit_index > 0 and cp.x > _points[_hit_index].x:
			continue
		draw_circle(cp, 9.0, UiTokens.AIM_OUTLINE, true, -1.0, false)
		draw_circle(cp, 6.0, UiTokens.DRONE_ROUTE, true, -1.0, false)
		# Encontro colado no canhao: o drone ja teria batido no tanque.
		if xm < shot.x_tank + MIN_INTERCEPT_M:
			continue
		var t := Ballistics.time_to(shot, xm)
		var fire_x := cp.x + route_speed * t
		if fire_x > RIGHT_EDGE - 8.0:
			continue
		var fp := _route_point(fire_x)
		var pulse := 13.0 + sin(_time * 5.0) * 2.0
		draw_arc(fp, pulse, 0, TAU, 24, UiTokens.AIM_OUTLINE, 5.0)
		draw_arc(fp, pulse, 0, TAU, 24, UiTokens.DRONE_ROUTE, 2.5)
		draw_line(fp, cp, Color(UiTokens.DRONE_ROUTE, 0.35), 1.5)
		if not labeled:
			labeled = true
			var tip := "drone aqui? atire! (a bala leva %s s)" % Ballistics.fmt(t)
			_place_label(
				[fp + Vector2(-60, 34), fp + Vector2(-60, -22)],
				tip,
				UiTokens.DRONE_ROUTE,
				UiTokens.FONT_XS
			)
	if xs.is_empty():
		var at := _route_point(640.0) + Vector2(0, 56)
		_place_label(
			[at, at + Vector2(0, 28)],
			"Δ < 0: a curva não encontra a rota",
			UiTokens.DRONE_ROUTE,
			UiTokens.FONT_XS
		)


func _draw_bounce_root() -> void:
	var r2 := Ballistics.root(_bounce_shot)
	if is_nan(r2):
		return
	var x: float = shot.origin_x_px + Ballistics.to_px(r2)
	if x > RIGHT_EDGE - 10.0:
		return
	var ground: float = shot.ground_y_px
	UiIcon.paint(self, "root", Rect2(Vector2(x - 4, ground - 22), Vector2(20, 20)), Color(aim, 0.8))
	_place_label(
		[Vector2(x + 14, ground - 26), Vector2(x - 120, ground - 26)],
		"quique: " + Ballistics.fmt(r2) + " m",
		Color(aim, 0.9),
		UiTokens.FONT_XS
	)


## A faixa de pouso no chao, com a desigualdade escrita. Fica verde forte
## quando a raiz da mira cai dentro dela.
func _draw_land_zone() -> void:
	var ground: float = shot.ground_y_px
	var x0: float = shot.origin_x_px + Ballistics.to_px(land_zone.x)
	var x1: float = shot.origin_x_px + Ballistics.to_px(land_zone.y)
	var r := Ballistics.root(shot)
	var inside := not is_nan(r) and r >= land_zone.x and r <= land_zone.y and _hit_index < 0
	var col := UiTokens.LAND_ZONE
	draw_rect(Rect2(x0, ground - 6, x1 - x0, 10), Color(col, 0.65 if inside else 0.35))
	for edge in [x0, x1]:
		draw_rect(Rect2(edge - 2, ground - 26, 4, 30), col)
	var text := "%s < x < %s" % [Ballistics.fmt(land_zone.x, 0), Ballistics.fmt(land_zone.y, 0)]
	if inside:
		text += "  dentro!"
	_label(Vector2(x0, ground - 32), text, col, UiTokens.FONT_SM)


func _draw_guess() -> void:
	var ground: float = shot.ground_y_px
	if is_nan(guess_x):
		var at := Vector2(pivot.x + 60.0, ground - 40.0)
		_label(
			at,
			"Calcule com a equação e clique no chão onde a bala vai cair!",
			UiTokens.EDITABLE,
			UiTokens.FONT_SM
		)
		return
	var x: float = shot.origin_x_px + Ballistics.to_px(guess_x)
	UiIcon.paint(
		self, "root", Rect2(Vector2(x - 6, ground - 30), Vector2(28, 28)), UiTokens.EDITABLE
	)
	draw_line(Vector2(x, ground - 2), Vector2(x, ground + 18), UiTokens.EDITABLE, 3.0)
	_label(
		Vector2(x + 18, ground - 34),
		"seu chute: " + Ballistics.fmt(guess_x) + " m",
		UiTokens.EDITABLE,
		UiTokens.FONT_SM
	)


## Arco do angulo junto ao canhao, em ambar (e o valor que o jogador gira).
func _draw_angle_arc() -> void:
	var ang: float = shot.angle_deg
	var r := 46.0
	var a1 := -deg_to_rad(ang)
	draw_line(pivot, pivot + Vector2(r + 10, 0), Color(UiTokens.EDITABLE, 0.55), 2.0)
	draw_arc(pivot, r, minf(0.0, a1), maxf(0.0, a1), 18, UiTokens.EDITABLE, 3.0)
	var mid := Vector2.RIGHT.rotated(a1 * 0.5) * (r + 14)
	_label(pivot + mid + Vector2(2, 6), "%d°" % roundi(ang), UiTokens.EDITABLE, UiTokens.FONT_SM)


## Colchete do "c": do chao ate o munhao, so no modo formula.
func _draw_cannon_height() -> void:
	var ground: float = shot.ground_y_px
	var x := pivot.x - 30.0
	draw_line(Vector2(x, ground), Vector2(x, pivot.y), aim, 2.0)
	draw_line(Vector2(x - 5, ground), Vector2(x + 5, ground), aim, 2.0)
	draw_line(Vector2(x - 5, pivot.y), Vector2(x + 5, pivot.y), aim, 2.0)
	_label(Vector2(x - 6, pivot.y - 8), "c", aim, UiTokens.FONT_SM, true)


func _hidden_rect(p: Vector2) -> Rect2:
	for r in occluders:
		if r.has_point(p):
			return r
	return Rect2()


## Escolhe o primeiro candidato cujo retangulo nao encosta na curva, num painel
## da HUD nem noutro rotulo; se nenhum servir, usa o primeiro.
func _place_label(candidates: Array, text: String, col: Color, size: int) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	for at in candidates:
		var rect := Rect2(at - Vector2(2, size), Vector2(w + 4, size + 6))
		if rect.position.x < 0.0 or rect.end.x > RIGHT_EDGE:
			continue
		if not _rect_blocked(rect):
			_label(at, text, col, size)
			return
	_label(candidates[0], text, col, size)


func _rect_blocked(rect: Rect2) -> bool:
	for r in _taken:
		if r.intersects(rect):
			return true
	var grown := rect.grow(4.0)
	for i in range(0, _points.size(), 2):
		if grown.has_point(_points[i]):
			return true
	return false


## Texto com contorno escuro, legivel sobre ceu, rocha ou chao.
func _label(at: Vector2, text: String, col: Color, size: int, align_right: bool = false) -> void:
	var pos := at
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if align_right:
		pos.x -= w
	draw_string_outline(
		_font,
		pos,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		UiTokens.TEXT_OUTLINE_SIZE + 2,
		UiTokens.TEXT_OUTLINE
	)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	_taken.append(Rect2(pos - Vector2(2, size), Vector2(w + 4, size + 6)))
