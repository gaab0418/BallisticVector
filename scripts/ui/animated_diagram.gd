class_name AnimatedDiagram
extends Control
## Desenho animado das paginas do Caderno da Ada, a tinta sobre papel. As
## curvas saem de Ballistics, a mesma conta da arena: o que a animacao mostra e
## o que acontece no jogo.

const CANNON_H := 1.0
const V := 800.0
const G := 500.0
const PERIOD := 4.0

var mode := "fly"
var params: Dictionary = {}
var _t := 0.0
var _font: Font
var _ink := UiTokens.INK
var _calc := UiTokens.CALCULATED_ON_PAPER
var _edit := UiTokens.EDITABLE_ON_PAPER
var _warm := UiTokens.DANGER_ON_PAPER
# Escala do desenho (definida a cada quadro conforme o modo).
var _span := 30.0
var _ppm := 10.0
var _ground := 0.0
var _x0 := 0.0


func _ready() -> void:
	_font = UiTheme.body_font(UiTokens.WEIGHT_BOLD)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(new_mode: String, new_params: Dictionary) -> void:
	mode = new_mode
	params = new_params
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _phase() -> float:
	return fposmod(_t, PERIOD) / PERIOD


## Vai e volta suave entre 0 e 1.
func _swing() -> float:
	return 0.5 - 0.5 * cos(_t * TAU / (PERIOD * 1.5))


func _shot(
	angle: float, speed: float, gravity: float, x_tank_m: float = 0.0, h: float = CANNON_H
) -> Dictionary:
	return Ballistics.shot(
		angle, speed, gravity, Vector2(Ballistics.to_px(x_tank_m), -Ballistics.to_px(h)), 0.0, 0.0
	)


func _to_screen(x: float, y: float) -> Vector2:
	return Vector2(_x0 + x * _ppm, _ground - y * _ppm)


func _setup_scale(span_m: float) -> void:
	_span = span_m
	_x0 = 24.0
	_ground = size.y - 30.0
	_ppm = (size.x - _x0 - 14.0) / _span


func _draw() -> void:
	match mode:
		"angles":
			_draw_angles()
		"power":
			_draw_power()
		"power_steps":
			_draw_power_steps()
		"sweep":
			_draw_sweep()
		"gravity":
			_draw_gravity()
		"planets":
			_draw_planets()
		"shift":
			_draw_shift()
		"line":
			_draw_line_mode()
		"flip":
			_draw_flip()
		"intercept":
			_draw_intercept()
		"bounce":
			_draw_bounce()
		"zone":
			_draw_zone()
		_:
			_draw_fly()


# ── Pecas comuns ─────────────────────────────────────────────────────


func _draw_ground() -> void:
	draw_line(Vector2(_x0 - 10, _ground), Vector2(size.x - 6, _ground), _ink, 2.0)
	var m := 0
	while _x0 + m * _ppm < size.x - 8:
		var x := _x0 + m * _ppm
		var tall := m % 5 == 0
		draw_line(Vector2(x, _ground), Vector2(x, _ground + (6.0 if tall else 3.0)), _ink, 1.0)
		if m % 10 == 0:
			_text(
				Vector2(x - 4, _ground + 20),
				str(m) + (" m" if m > 0 else ""),
				Color(_ink, 0.8),
				UiTokens.FONT_XS
			)
		m += 1


func _curve(s: Dictionary, col: Color, width: float, upto: float = INF) -> Vector2:
	var end := Ballistics.root(s)
	if is_nan(end):
		end = _span
	end = minf(end, upto)
	var pts := PackedVector2Array()
	var steps := 60
	var x0: float = s.x_tank
	for i in range(steps + 1):
		var x := x0 + (end - x0) * i / steps
		pts.append(_to_screen(x, Ballistics.y_at(s, x)))
	if pts.size() > 1:
		draw_polyline(pts, col, width)
	return pts[pts.size() - 1]


func _bullet(p: Vector2) -> void:
	draw_circle(p, 5.0, UiTokens.INK, true, -1.0, false)
	draw_circle(p, 3.0, UiTokens.BRASS, true, -1.0, false)


func _vertex(s: Dictionary, col: Color, label: String = "") -> void:
	if not Ballistics.has_arc(s):
		return
	var v := Ballistics.vertex(s)
	var p := _to_screen(v.x, v.y)
	draw_dashed_line(p, Vector2(p.x, _ground), Color(col, 0.6), 1.5, 5.0)
	UiIcon.paint(self, "vertex", Rect2(p - Vector2(8, 8), Vector2(16, 16)), col, false)
	if label != "":
		_text(p + Vector2(12, -6), label, col, UiTokens.FONT_SM)


func _flag(s: Dictionary, col: Color, label: String = "") -> void:
	var r := Ballistics.root(s)
	if is_nan(r):
		return
	var p := _to_screen(r, 0.0)
	UiIcon.paint(self, "root", Rect2(p - Vector2(4, 22), Vector2(20, 20)), col, false)
	if label != "":
		_text(p + Vector2(-20, -28), label, col, UiTokens.FONT_SM)


func _text(at: Vector2, txt: String, col: Color, size_px: int) -> void:
	draw_string(_font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


# ── Modos ────────────────────────────────────────────────────────────


## A bala voa pela curva; vertice e raiz aparecem quando ela passa por eles.
func _draw_fly() -> void:
	_setup_scale(30.0)
	_draw_ground()
	var angle: float = params.get("angle", 45.0)
	if params.get("wobble", false):
		angle += sin(_t * 0.8) * 12.0
	var s := _shot(angle, V, G)
	_curve(s, Color(_calc, 0.25), 2.0)
	var r := Ballistics.root(s)
	var k := minf(_phase() * 1.25, 1.0)
	var head := _curve(s, _calc, 3.0, r * k)
	if k < 1.0:
		_bullet(head)
	if Ballistics.vertex(s).x <= r * k or params.get("mark", "") == "vertex":
		_vertex(s, _calc, "vértice: %s m" % Ballistics.fmt(Ballistics.vertex(s).y))
	if k >= 1.0:
		_flag(s, _calc, "raiz: %s m" % Ballistics.fmt(r))


func _draw_angles() -> void:
	_setup_scale(30.0)
	_draw_ground()
	var list: Array = params.get("list", [30.0, 60.0])
	var cols := [_edit, _warm]
	var k := _phase() * 1.4
	for i in range(list.size()):
		var s := _shot(list[i], V, G)
		var part := clampf(k - i * 0.5, 0.0, 1.0)
		if part > 0.0:
			_curve(s, cols[i], 3.0, Ballistics.root(s) * part)
			_text(
				_to_screen(Ballistics.vertex(s).x, Ballistics.vertex(s).y) + Vector2(-10, -10),
				"%d°" % roundi(list[i]),
				cols[i],
				UiTokens.FONT_SM
			)
		if part >= 1.0:
			_flag(s, cols[i])
	if k > 1.6:
		var r := Ballistics.root(_shot(list[0], V, G))
		_text(_to_screen(r, 0) + Vector2(-60, -40), "mesmo lugar!", _calc, UiTokens.FONT_MD)


func _draw_power() -> void:
	_setup_scale(32.0)
	_draw_ground()
	var pw := 0.5 + 0.5 * _swing()
	var s := _shot(40.0, V * pw, G)
	_curve(s, Color(_calc, 0.2), 2.0)
	_curve(_shot(40.0, V * 0.5, G), Color(_ink, 0.25), 1.5)
	_curve(s, _calc, 3.0)
	_flag(s, _calc, "%s m" % Ballistics.fmt(Ballistics.root(s)))
	_text(Vector2(_x0, 24), "força %d%%" % roundi(pw * 100.0), _edit, UiTokens.FONT_MD)


func _draw_power_steps() -> void:
	_setup_scale(32.0)
	_draw_ground()
	var cols := [_ink, _warm, _calc]
	var k := _phase() * 1.6
	for i in range(3):
		var pw: float = [0.6, 0.8, 1.0][i]
		var s := _shot(35.0, V * pw, G)
		var part := clampf(k - i * 0.4, 0.0, 1.0)
		if part > 0.0:
			_curve(s, cols[i], 2.5, Ballistics.root(s) * part)
		if part >= 1.0:
			_flag(s, cols[i], "%d%%" % roundi(pw * 100.0))


func _draw_sweep() -> void:
	_setup_scale(30.0)
	_draw_ground()
	var best := _shot(45.0, V, G)
	_curve(best, Color(_calc, 0.25), 2.0)
	_flag(best, Color(_calc, 0.5))
	var angle := 15.0 + 60.0 * _swing()
	var s := _shot(angle, V, G)
	_curve(s, _edit, 3.0)
	_flag(s, _edit)
	_text(
		Vector2(_x0, 24),
		"%d°  →  %s m" % [roundi(angle), Ballistics.fmt(Ballistics.root(s))],
		_edit,
		UiTokens.FONT_MD
	)


func _draw_gravity() -> void:
	var g_from: float = params.get("from", 80.0)
	var g_to: float = params.get("to", 490.0)
	var speed := 520.0
	var widest := Ballistics.root(_shot(45.0, speed, minf(g_from, g_to)))
	_setup_scale(maxf(widest * 1.1, 8.0))
	_draw_ground()
	var g := lerpf(g_from, g_to, _swing())
	var s := _shot(45.0, speed, g)
	_curve(s, _calc, 3.0)
	_vertex(s, _calc)
	_flag(s, _calc)
	var planet := Campaign.planet_like(Ballistics.to_m(g))
	var label := "g = %s m/s²" % Ballistics.fmt(Ballistics.to_m(g))
	if planet != "":
		label += "  (" + planet + ")"
	_text(Vector2(_x0, 24), label, _edit, UiTokens.FONT_MD)


func _draw_planets() -> void:
	_setup_scale(22.0)
	_draw_ground()
	var list := [["Marte", 185.0, _warm], ["Terra", 490.0, _calc], ["Júpiter", 1240.0, _ink]]
	var k := _phase() * 1.6
	for i in range(list.size()):
		var s := _shot(45.0, 420.0, list[i][1])
		var part := clampf(k - i * 0.4, 0.0, 1.0)
		if part > 0.0:
			_curve(s, list[i][2], 2.5, Ballistics.root(s) * part)
		if part >= 1.0:
			_flag(s, list[i][2], list[i][0])


func _draw_shift() -> void:
	_setup_scale(30.0)
	_draw_ground()
	var xt := 7.0 * _swing()
	var s := _shot(50.0, 640.0, G, xt)
	_curve(s, _calc, 3.0)
	var tank := _to_screen(xt, 0)
	draw_rect(Rect2(tank - Vector2(10, 10), Vector2(20, 10)), UiTokens.OLIVE)
	_text(Vector2(_x0, 24), "a = %s  (igual!)" % Ballistics.fmt(s.a, 3), _calc, UiTokens.FONT_SM)
	_text(
		Vector2(_x0, 46),
		"b = %s    c = %s" % [Ballistics.fmt(s.b, 2), Ballistics.fmt(s.c, 1)],
		_edit,
		UiTokens.FONT_SM
	)
	if params.get("show_hk", false):
		var v := Ballistics.vertex(s)
		_vertex(s, _warm, "(h, k) = (%s ; %s)" % [Ballistics.fmt(v.x), Ballistics.fmt(v.y)])


func _draw_line_mode() -> void:
	_setup_scale(30.0)
	_draw_ground()
	var angle: float = params.get("angle", 45.0)
	var s := _shot(angle, V, G)
	var h: float = Ballistics.vertex(s).y if params.get("touch", false) else params.get("h", 5.0)
	var y := _to_screen(0, h).y
	draw_dashed_line(Vector2(_x0 - 6, y), Vector2(size.x - 8, y), _edit, 2.0, 8.0)
	_text(Vector2(_x0, y - 8), "y = %s" % Ballistics.fmt(h, 1), _edit, UiTokens.FONT_SM)
	var k := minf(_phase() * 1.25, 1.0)
	var head := _curve(s, _calc, 3.0, Ballistics.root(s) * k)
	if k < 1.0:
		_bullet(head)
	for xm in Ballistics.crossings(s, h):
		if xm <= Ballistics.root(s) * k + 0.01:
			var p := _to_screen(xm, h)
			draw_circle(p, 6.0, _edit, true, -1.0, false)
			draw_arc(p, 6.0, 0, TAU, 12, _ink, 1.5)


func _draw_flip() -> void:
	_setup_scale(24.0)
	_draw_ground()
	var s := _shot(-30.0, 760.0, -400.0, 0.0, 5.0)
	var k := minf(_phase() * 1.25, 1.0)
	var head := _curve(s, _calc, 3.0, 22.0 * k)
	if k < 1.0:
		_bullet(head)
	var c := _to_screen(0, 5.0)
	draw_rect(Rect2(c - Vector2(16, -8), Vector2(26, 30)), UiTokens.ROCK)
	if params.get("mark", "") == "vertex" or Ballistics.vertex(s).x < 22.0 * k:
		_vertex(s, _warm, "vértice: o ponto mais baixo")


## A rota reta do drone e a parabola: os encontros sao as solucoes. Com
## "drone", um drone anda pela reta e chega no encontro junto com a bala.
func _draw_intercept() -> void:
	_setup_scale(30.0)
	_draw_ground()
	var m: float = params.get("m", 0.15)
	var n: float = params.get("n", 2.0)
	var a := _to_screen(0, n)
	var b := _to_screen(_span, n + m * _span)
	draw_dashed_line(a, b, _warm, 2.0, 8.0)
	_text(
		a + Vector2(4, -8),
		"y = %sx + %s" % [Ballistics.fmt(m, 2), Ballistics.fmt(n, 0)],
		_warm,
		UiTokens.FONT_SM
	)
	var s := _shot(42.0, V, G)
	var k := minf(_phase() * 1.25, 1.0)
	var r := Ballistics.root(s)
	var head := _curve(s, _calc, 3.0, r * k)
	if k < 1.0:
		_bullet(head)
	var xs := Ballistics.crossings_line(s, m, n)
	for xm in xs:
		if xm <= r * k + 0.01:
			var p := _to_screen(xm, Ballistics.y_at(s, xm))
			draw_circle(p, 6.0, _warm, true, -1.0, false)
			draw_arc(p, 6.0, 0, TAU, 12, _ink, 1.5)
	if params.get("drone", false) and xs.size() > 1:
		# O drone chega ao segundo encontro no mesmo instante que a bala.
		var meet: float = xs[1]
		var t_meet := Ballistics.time_to(s, meet)
		var t_now := Ballistics.time_to(s, r * k)
		var dx := 4.0 * (t_meet - t_now)
		var xd := meet + dx
		if xd < _span:
			var dp := _to_screen(xd, n + m * xd)
			draw_rect(Rect2(dp - Vector2(8, 4), Vector2(16, 8)), _warm)
			draw_rect(Rect2(dp - Vector2(10, 2), Vector2(4, 4)), _ink)


## A bala quica e faz outra parabola com o mesmo "a", mais baixa.
func _draw_bounce() -> void:
	_setup_scale(36.0)
	_draw_ground()
	var s := _shot(50.0, 640.0, G)
	var s2 := Ballistics.bounce(s, 0.55)
	var r := Ballistics.root(s)
	var r2 := Ballistics.root(s2)
	var k := minf(_phase() * 1.3, 1.0)
	var x_now := lerpf(s.x_tank, r2, k)
	var head := _curve(s, _calc, 3.0, minf(x_now, r))
	if x_now > r:
		head = _curve(s2, _edit, 3.0, x_now)
	if k < 1.0:
		_bullet(head)
	_vertex(s, _calc)
	if x_now > r:
		_vertex(s2, _edit)
	_text(Vector2(_x0, 24), "a = %s nas duas!" % Ballistics.fmt(s.a, 3), _calc, UiTokens.FONT_SM)


## A faixa de pouso: so as curvas com a raiz dentro dela acendem.
func _draw_zone() -> void:
	_setup_scale(24.0)
	_draw_ground()
	var lo: float = params.get("from", 12.0)
	var hi: float = params.get("to", 15.0)
	var x0 := _to_screen(lo, 0).x
	var x1 := _to_screen(hi, 0).x
	draw_rect(Rect2(x0, _ground - 6, x1 - x0, 8), Color(UiTokens.LAND_ZONE.darkened(0.3), 0.7))
	_text(
		Vector2(x0 - 6, _ground - 64),
		"%s < x < %s" % [Ballistics.fmt(lo, 0), Ballistics.fmt(hi, 0)],
		_ink,
		UiTokens.FONT_SM
	)
	var pw := 0.55 + 0.4 * _swing()
	var s := _shot(45.0, 640.0 * pw, G)
	var r := Ballistics.root(s)
	var inside := r >= lo and r <= hi
	_curve(s, _calc if inside else Color(_ink, 0.45), 3.0)
	_flag(
		s,
		_calc if inside else _warm,
		("dentro!" if inside else "fora") + " (%s m)" % Ballistics.fmt(r)
	)
