class_name ParabolaDiagram
extends Control
## Mini-grafico de parabolas, desenhado a tinta sobre papel, para a tela de ajuda.
##
## As curvas vem de Ballistics -- a mesma conta da arena --, entao o que a ajuda
## mostra ("30° e 60° caem no mesmo lugar") e exatamente o que acontece no jogo.
##
## `curves`: lista de {angle, speed, gravity, color, label, label_at, label_dy}. `annotate` liga os
## rotulos de vertice, raiz e altura do canhao (diagrama principal).

## Altura do canhao no diagrama, em metros (a mesma da arena).
const CANNON_H := 1.0

var curves: Array = []
var annotate := false
## Metros que cabem na largura do grafico.
var span_m := 28.0
var _font: Font


func _ready() -> void:
	_font = UiTheme.body_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var pad := Vector2(28, 18)
	var ground := size.y - pad.y - 18.0
	var origin_x := pad.x
	var ppm := (size.x - pad.x * 2.0) / span_m
	var ink := UiTokens.INK

	# Chao com regua e eixo da altura.
	draw_line(Vector2(origin_x - 10, ground), Vector2(size.x - 6, ground), ink, 2.0)
	draw_line(Vector2(origin_x, ground + 6), Vector2(origin_x, pad.y - 4), Color(ink, 0.5), 1.0)
	var m := 0
	while origin_x + m * ppm < size.x - 8:
		var x := origin_x + m * ppm
		draw_line(Vector2(x, ground), Vector2(x, ground + (6.0 if m % 5 == 0 else 3.0)), ink, 1.0)
		if m % 10 == 0:
			_text(
				Vector2(x - 4, ground + 20), str(m) + (" m" if m > 0 else ""), ink, UiTokens.FONT_XS
			)
		m += 1

	for c in curves:
		_draw_curve(c, origin_x, ground, ppm)


func _draw_curve(c: Dictionary, origin_x: float, ground: float, ppm: float) -> void:
	var col: Color = c.color
	var s := Ballistics.shot(
		c.angle, c.speed, c.gravity, Vector2(0, -Ballistics.to_px(CANNON_H)), 0.0, 0.0
	)
	var r := Ballistics.root(s)
	var pts := PackedVector2Array()
	var steps := 60
	for i in range(steps + 1):
		var x := r * i / steps
		pts.append(Vector2(origin_x + x * ppm, ground - Ballistics.y_at(s, x) * ppm))
	draw_polyline(pts, col, 3.0)

	var root_p := Vector2(origin_x + r * ppm, ground)
	UiIcon.paint(self, "root", Rect2(root_p - Vector2(4, 22), Vector2(20, 20)), col, false)
	var v := Ballistics.vertex(s)
	var vp := Vector2(origin_x + v.x * ppm, ground - v.y * ppm)
	UiIcon.paint(self, "vertex", Rect2(vp - Vector2(8, 8), Vector2(16, 16)), col, false)

	# Rotulo no vertice ou na raiz ("label_at"): onde as curvas se separam mais.
	if c.has("label"):
		if c.get("label_at", "vertex") == "root":
			var dy: float = c.get("label_dy", 0.0)
			_text(root_p + Vector2(-6, -26 + dy), c.label, col, UiTokens.FONT_XS)
		else:
			_text(vp + Vector2(10, -6), c.label, col, UiTokens.FONT_XS)

	if annotate:
		var drop := PackedVector2Array([vp, Vector2(vp.x, ground)])
		draw_dashed_line(drop[0], drop[1], Color(col, 0.6), 2.0, 6.0)
		_text(vp + Vector2(14, 4), "vértice: o ponto mais alto", col, UiTokens.FONT_SM)
		_text(vp + Vector2(14, 26), "(a altura máxima)", col, UiTokens.FONT_XS)
		_text(root_p + Vector2(-150, -34), "raiz: onde cai (o alcance)", col, UiTokens.FONT_SM)
		var cx := origin_x - 14.0
		var top := ground - CANNON_H * ppm
		draw_line(Vector2(cx, ground), Vector2(cx, top), UiTokens.EDITABLE_ON_PAPER, 2.0)
		_text(Vector2(cx - 12, top - 6), "c", UiTokens.EDITABLE_ON_PAPER, UiTokens.FONT_SM)


func _text(at: Vector2, text: String, col: Color, size_px: int) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
