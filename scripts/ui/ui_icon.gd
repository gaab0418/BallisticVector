@tool
class_name UiIcon
extends Control
## Icone desenhado em codigo, numa grade de 16x16 escalada para o tamanho do no.
##
## Cobre simbolos que as fontes nao tem (◆, ★, ✓, cadeado) e garante que os
## marcadores da parabola (vertice e raiz) sejam o MESMO desenho na HUD e na
## linha de mira: o desenho mora em paint(), que a trajetoria tambem chama.
##
## Todo icone recebe contorno escuro de um "pixel" para destacar do fundo.

const NAMES := [
	"vertex",
	"root",
	"star",
	"star_empty",
	"shield",
	"lock",
	"check",
	"gear",
	"angle",
	"force",
	"planet",
	"move",
	"target",
	"arrow_up",
	"arrow_right",
	"cross",
	"formula",
	"parabola",
]

@export var icon := "star":
	set(value):
		icon = value
		queue_redraw()
@export var color := UiTokens.TEXT:
	set(value):
		color = value
		queue_redraw()
@export var outlined := true:
	set(value):
		outlined = value
		queue_redraw()
## Rotacao do desenho em radianos, em volta do centro. A engrenagem da HUD gira por aqui.
var spin := 0.0:
	set(value):
		spin = value
		queue_redraw()


static func make(icon_name: String, tint: Color, side: float = 24.0) -> UiIcon:
	var node := UiIcon.new()
	node.icon = icon_name
	node.color = tint
	node.custom_minimum_size = Vector2(side, side)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	if spin != 0.0:
		var c := rect.get_center()
		draw_set_transform(c, spin, Vector2.ONE)
		rect.position -= c
	paint(self, icon, rect, color, outlined)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Desenha `icon_name` dentro de `rect` em qualquer CanvasItem. O contorno sai
## de desenhar a forma deslocada nas quatro direcoes antes da forma colorida.
static func paint(
	ci: CanvasItem, icon_name: String, rect: Rect2, tint: Color, with_outline: bool = true
) -> void:
	if with_outline:
		var o := maxf(1.0, rect.size.x / 16.0)
		for d in [Vector2(o, 0), Vector2(-o, 0), Vector2(0, o), Vector2(0, -o)]:
			_shape(ci, icon_name, Rect2(rect.position + d, rect.size), UiTokens.NIGHT_950, true)
	_shape(ci, icon_name, rect, tint, false)


static func _g(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x, y) * r.size / 16.0


static func _poly(ci: CanvasItem, r: Rect2, pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_g(r, p.x, p.y))
	ci.draw_colored_polygon(out, col)


static func _box(
	ci: CanvasItem, r: Rect2, x0: float, y0: float, x1: float, y1: float, col: Color
) -> void:
	var a := _g(r, x0, y0)
	ci.draw_rect(Rect2(a, _g(r, x1, y1) - a), col)


static func _line(ci: CanvasItem, r: Rect2, pts: Array, col: Color, w: float) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_g(r, p.x, p.y))
	ci.draw_polyline(out, col, w * r.size.x / 16.0)


static func _star_points(cx: float, cy: float, ro: float, ri: float) -> Array:
	var pts := []
	for i in range(10):
		var ang := -PI / 2.0 + i * PI / 5.0
		var rad := ro if i % 2 == 0 else ri
		pts.append(Vector2(cx + cos(ang) * rad, cy + sin(ang) * rad))
	return pts


## `shadow` = esta passada e o contorno: detalhes internos (furos, brilhos) nao
## sao desenhados nela, so a silhueta.
static func _shape(ci: CanvasItem, n: String, r: Rect2, col: Color, shadow: bool) -> void:
	var u := r.size.x / 16.0
	match n:
		"vertex":
			_poly(ci, r, [Vector2(8, 1), Vector2(15, 8), Vector2(8, 15), Vector2(1, 8)], col)
			if not shadow:
				_poly(
					ci,
					r,
					[Vector2(8, 4), Vector2(11, 8), Vector2(8, 8), Vector2(5, 8)],
					UiTokens.SHINE
				)
		"root":
			_box(ci, r, 3, 1, 5, 14, col)
			_poly(ci, r, [Vector2(5, 1.5), Vector2(15, 4.5), Vector2(5, 8)], col)
			_box(ci, r, 1, 13.5, 8, 15.5, col)
		"star":
			_poly(ci, r, _star_points(8, 8.6, 7.6, 3.4), col)
		"star_empty":
			# So contorno: com miolo escuro, sobre papel ela pareceria cheia.
			var pts := _star_points(8, 8.6, 6.8, 3.0)
			pts.append(pts[0])
			_line(ci, r, pts, col, 1.8)
		"shield":
			_poly(
				ci,
				r,
				[Vector2(2, 2), Vector2(14, 2), Vector2(14, 8), Vector2(8, 15), Vector2(2, 8)],
				col
			)
			if not shadow:
				_poly(
					ci,
					r,
					[Vector2(8, 3.5), Vector2(12.5, 3.5), Vector2(12.5, 8), Vector2(8, 13)],
					UiTokens.SHADE
				)
		"lock":
			ci.draw_arc(_g(r, 8, 7.5), 3.6 * u, PI, TAU, 12, col, 2.2 * u)
			_box(ci, r, 2.5, 7, 13.5, 15, col)
			if not shadow:
				_box(ci, r, 7, 9.5, 9, 12.5, UiTokens.NIGHT_950)
		"check":
			_line(ci, r, [Vector2(2, 8.5), Vector2(6.5, 13), Vector2(14.5, 3)], col, 3.0)
		"cross":
			_line(ci, r, [Vector2(3, 3), Vector2(13, 13)], col, 3.0)
			_line(ci, r, [Vector2(13, 3), Vector2(3, 13)], col, 3.0)
		"gear":
			_gear(ci, r, col, shadow)
		"angle":
			_line(ci, r, [Vector2(13, 3), Vector2(2, 14), Vector2(15, 14)], col, 2.2)
			ci.draw_arc(_g(r, 2, 14), 7.0 * u, -PI / 4.0, 0.0, 8, col, 1.8 * u)
		"force":
			_poly(ci, r, [Vector2(6, 4), Vector2(15, 8), Vector2(6, 12)], col)
			_box(ci, r, 1, 7, 6, 9, col)
			_box(ci, r, 2, 3.5, 5, 5, col)
			_box(ci, r, 2, 11, 5, 12.5, col)
		"planet":
			ci.draw_circle(_g(r, 8, 8), 5.0 * u, col)
			_line(ci, r, [Vector2(0.5, 11), Vector2(8, 8.5), Vector2(15.5, 5)], col, 1.8)
			if not shadow:
				ci.draw_circle(_g(r, 6.5, 6.5), 1.4 * u, UiTokens.SHINE)
		"move":
			_poly(ci, r, [Vector2(1, 8), Vector2(5.5, 3.5), Vector2(5.5, 12.5)], col)
			_poly(ci, r, [Vector2(15, 8), Vector2(10.5, 3.5), Vector2(10.5, 12.5)], col)
			_box(ci, r, 5, 7, 11, 9, col)
		"target":
			ci.draw_arc(_g(r, 8, 8), 6.0 * u, 0.0, TAU, 20, col, 2.0 * u)
			ci.draw_circle(_g(r, 8, 8), 2.4 * u, col)
		"arrow_up":
			_poly(ci, r, [Vector2(8, 1), Vector2(15, 9), Vector2(1, 9)], col)
			_box(ci, r, 5.5, 9, 10.5, 15, col)
		"arrow_right":
			_poly(ci, r, [Vector2(15, 8), Vector2(7, 1), Vector2(7, 15)], col)
			_box(ci, r, 1, 5.5, 7, 10.5, col)
		"parabola":
			var pts := []
			for i in range(9):
				var t := -1.0 + 2.0 * i / 8.0
				pts.append(Vector2(8 + t * 6.5, 3 + t * t * 10))
			_line(ci, r, pts, col, 2.4)
		"formula":
			_line(
				ci, r, [Vector2(11, 2), Vector2(8, 2), Vector2(6.5, 14), Vector2(4, 14)], col, 2.0
			)
			_box(ci, r, 4, 7, 11, 8.6, col)


## Engrenagem de 8 dentes com miolo escuro.
static func _gear(ci: CanvasItem, r: Rect2, col: Color, shadow: bool) -> void:
	var c := _g(r, 8, 8)
	var u := r.size.x / 16.0
	var teeth := 8
	var pts := PackedVector2Array()
	for i in range(teeth):
		var a0 := TAU * i / teeth
		var half := PI / teeth
		for k in [-0.55, -0.32, 0.32, 0.55]:
			var rad: float = 7.6 * u if absf(k) < 0.4 else 5.6 * u
			var ang: float = a0 + k * half * 1.6
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	ci.draw_colored_polygon(pts, col)
	if shadow:
		return
	ci.draw_circle(c, 3.0 * u, col.darkened(0.45))
	ci.draw_circle(c, 1.4 * u, col.lightened(0.3))
