class_name WarTable
extends Control
## O mapa de guerra: um pergaminho sobre a mesa de comando, desenhado em codigo.
##
## O mapa e um PLANO CARTESIANO: grade quadriculada, eixos x e y numerados, e
## cada base numa ilha com coordenadas inteiras. As rotas entre as bases sao
## arcos de parabola. Ou seja, ate a tela de escolher fase fala a lingua do jogo.
##
## Substitui a imagem de carta nautica, que era recortada em "cover" (perdia as
## bordas conforme a proporcao da janela) e nao tinha relacao com a materia.
## Aqui tudo e calculado a partir do tamanho atual: nada e cortado, em nenhuma
## resolucao.

const GRID_W := 20
const GRID_H := 9
const PAD := 44.0
const ISLAND_R := 1.75

## Ilhas e o que cada uma tem desenhado, na ordem dos capitulos.
## biome: hills (Alpha, angulo), forest (Bravo, forca), craters (Charlie,
## gravidade), road (Delta, translacao).
const ISLANDS := [
	{"grid": Vector2(4, 6), "biome": "hills"},
	{"grid": Vector2(8, 2), "biome": "forest"},
	{"grid": Vector2(13, 6), "biome": "craters"},
	{"grid": Vector2(17, 3), "biome": "road"},
]
## Ilhotas decorativas, sem base.
const ISLETS := [Vector2(10.5, 3.2), Vector2(1.6, 2.2), Vector2(18.8, 7.4), Vector2(6.6, 8.0)]

var top_margin := 70.0
var bottom_margin := 86.0
## Trechos de rota ja percorridos (base anterior conquistada).
var done_routes: Array = [false, false, false]

var _font: Font
var _title_font: Font
var _paper := Rect2()
var _origin := Vector2.ZERO
var _cell := 50.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.body_font()
	_title_font = UiTheme.title_font()
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_paper = Rect2(Vector2(26, top_margin), size - Vector2(52, top_margin + bottom_margin))
	var plot := _paper.grow(-PAD)
	_cell = minf(plot.size.x / GRID_W, plot.size.y / GRID_H)
	var used := Vector2(GRID_W, GRID_H) * _cell
	_origin = Vector2(
		plot.position.x + (plot.size.x - used.x) * 0.5, plot.end.y - (plot.size.y - used.y) * 0.5
	)
	queue_redraw()


## Ponto do plano cartesiano (x para a direita, y para cima) em pixels de tela.
func grid_to_screen(g: Vector2) -> Vector2:
	return _origin + Vector2(g.x, -g.y) * _cell


func cell_size() -> float:
	return _cell


func _draw() -> void:
	_draw_table()
	_draw_paper()
	_draw_sea()
	_draw_grid()
	for p in ISLETS:
		_draw_island(grid_to_screen(p), _cell * 0.55, int(p.x * 13 + p.y * 7), "")
	for i in range(ISLANDS.size()):
		var isl: Dictionary = ISLANDS[i]
		_draw_island(grid_to_screen(isl.grid), _cell * ISLAND_R, 31 + i * 17, isl.biome)
	_draw_routes()
	_draw_compass(grid_to_screen(Vector2(GRID_W - 1.2, GRID_H - 1.4)), _cell * 0.9)
	_ink_text(grid_to_screen(Vector2(9.2, 7.6)), "Mar das Parábolas", UiTokens.FONT_MD, 0.55, true)


# ═════════════════════════════════════════════════════════════════════
#  MESA E PERGAMINHO
# ═════════════════════════════════════════════════════════════════════


## Tampo de madeira em tabuas horizontais, com veios.
func _draw_table() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTokens.WOOD_DARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var plank := 44.0
	var y := 0.0
	var i := 0
	while y < size.y:
		var col := UiTokens.WOOD if i % 2 == 0 else UiTokens.WOOD.darkened(0.08)
		draw_rect(Rect2(0, y, size.x, plank - 2), col)
		for k in range(10):
			var gx := rng.randf_range(0, size.x)
			var gy := y + rng.randf_range(6, plank - 8)
			draw_line(
				Vector2(gx, gy), Vector2(gx + rng.randf_range(60, 220), gy), UiTokens.WOOD_DARK, 1.0
			)
		y += plank
		i += 1


## Pergaminho de bordas irregulares, com sombra, manchas e borda envelhecida.
func _draw_paper() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var edge := _ragged(_paper, rng)
	var shadow := PackedVector2Array()
	for p in edge:
		shadow.append(p + Vector2(7, 9))
	draw_colored_polygon(shadow, UiTokens.SHADOW)
	draw_colored_polygon(edge, UiTokens.PAPER)
	# Borda escurecida em aneis: o papel envelhece de fora para dentro.
	for k in range(6):
		var ring := PackedVector2Array()
		var inset := 4.0 + k * 5.0
		var r := _paper.grow(-inset)
		for p in edge:
			ring.append(p.clamp(r.position, r.end))
		ring.append(ring[0])
		draw_polyline(ring, Color(UiTokens.PAPER_DARK, 0.22 - k * 0.03), 6.0)
	for k in range(7):
		var c := Vector2(
			rng.randf_range(_paper.position.x + 60, _paper.end.x - 60),
			rng.randf_range(_paper.position.y + 40, _paper.end.y - 40)
		)
		draw_circle(c, rng.randf_range(18, 46), Color(UiTokens.PAPER_DARK, 0.12), true, -1.0, false)
	var outline := edge.duplicate()
	outline.append(edge[0])
	draw_polyline(outline, Color(UiTokens.INK, 0.6), 2.0)


func _ragged(r: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step := 16.0
	var x := r.position.x
	while x < r.end.x:
		pts.append(Vector2(x, r.position.y + rng.randf_range(0, 5)))
		x += step
	var y := r.position.y
	while y < r.end.y:
		pts.append(Vector2(r.end.x - rng.randf_range(0, 5), y))
		y += step
	x = r.end.x
	while x > r.position.x:
		pts.append(Vector2(x, r.end.y - rng.randf_range(0, 5)))
		x -= step
	y = r.end.y
	while y > r.position.y:
		pts.append(Vector2(r.position.x + rng.randf_range(0, 5), y))
		y -= step
	return pts


## Aguada de mar sobre a area do plano e ondinhas a tinta longe das ilhas.
func _draw_sea() -> void:
	var a := grid_to_screen(Vector2(0, GRID_H))
	var b := grid_to_screen(Vector2(GRID_W, 0))
	draw_rect(Rect2(a, b - a), UiTokens.MAP_SEA)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in range(70):
		var g := Vector2(rng.randf_range(0.5, GRID_W - 0.5), rng.randf_range(0.4, GRID_H - 0.4))
		if _near_island(g):
			continue
		var p := grid_to_screen(g)
		var w := _cell * 0.18
		var ink := Color(UiTokens.INK, 0.28)
		draw_arc(p, w, PI * 1.15, PI * 1.85, 6, ink, 1.2)
		draw_arc(p + Vector2(w * 1.6, 0), w, PI * 1.15, PI * 1.85, 6, ink, 1.2)


func _near_island(g: Vector2) -> bool:
	for isl in ISLANDS:
		if g.distance_to(isl.grid) < ISLAND_R * 1.35:
			return true
	for p in ISLETS:
		if g.distance_to(p) < 1.0:
			return true
	return g.distance_to(Vector2(GRID_W - 1.2, GRID_H - 1.4)) < 1.3


# ═════════════════════════════════════════════════════════════════════
#  PLANO CARTESIANO
# ═════════════════════════════════════════════════════════════════════


func _draw_grid() -> void:
	var faint := Color(UiTokens.INK, 0.1)
	for gx in range(GRID_W + 1):
		draw_line(grid_to_screen(Vector2(gx, 0)), grid_to_screen(Vector2(gx, GRID_H)), faint, 1.0)
	for gy in range(GRID_H + 1):
		draw_line(grid_to_screen(Vector2(0, gy)), grid_to_screen(Vector2(GRID_W, gy)), faint, 1.0)

	# Eixos com seta, como no caderno.
	var ink := Color(UiTokens.INK, 0.75)
	var o := grid_to_screen(Vector2.ZERO)
	var xe := grid_to_screen(Vector2(GRID_W + 0.4, 0))
	var ye := grid_to_screen(Vector2(0, GRID_H + 0.4))
	draw_line(o, xe, ink, 2.0)
	draw_line(o, ye, ink, 2.0)
	draw_colored_polygon(PackedVector2Array([xe, xe + Vector2(-10, -5), xe + Vector2(-10, 5)]), ink)
	draw_colored_polygon(PackedVector2Array([ye, ye + Vector2(-5, 10), ye + Vector2(5, 10)]), ink)
	_ink_text(xe + Vector2(-6, 22), "x", UiTokens.FONT_MD, 0.85, false)
	_ink_text(ye + Vector2(-22, 6), "y", UiTokens.FONT_MD, 0.85, false)

	for gx in range(0, GRID_W + 1, 2):
		var p := grid_to_screen(Vector2(gx, 0))
		draw_line(p, p + Vector2(0, 5), ink, 1.0)
		_ink_text(p + Vector2(-4, 20), str(gx), UiTokens.FONT_XS, 0.7, false)
	for gy in range(1, GRID_H + 1):
		var p := grid_to_screen(Vector2(0, gy))
		draw_line(p, p + Vector2(-5, 0), ink, 1.0)
		_ink_text(p + Vector2(-20, 6), str(gy), UiTokens.FONT_XS, 0.7, false)


# ═════════════════════════════════════════════════════════════════════
#  ILHAS
# ═════════════════════════════════════════════════════════════════════


## Ilha em forma de bolha irregular: terra clara, costa a tinta e duas linhas
## de agua em volta, como nas cartas nauticas antigas.
func _draw_island(c: Vector2, radius: float, seed_value: int, biome: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var shape := PackedVector2Array()
	for i in range(72):
		var a := TAU * i / 72.0
		var k := 1.0 + 0.16 * sin(3.0 * a + ph[0]) + 0.09 * sin(5.0 * a + ph[1])
		k += 0.04 * sin(11.0 * a + ph[2])
		shape.append(c + Vector2(cos(a), sin(a) * 0.78) * radius * k)

	for w in [14.0, 7.0]:
		var ripple := PackedVector2Array()
		for p in shape:
			ripple.append(c + (p - c) * (1.0 + w / radius))
		ripple.append(ripple[0])
		draw_polyline(ripple, Color(UiTokens.INK, 0.14 if w > 10.0 else 0.25), 1.0)

	draw_colored_polygon(shape, UiTokens.MAP_LAND)
	var coast := shape.duplicate()
	coast.append(shape[0])
	draw_polyline(coast, Color(UiTokens.INK, 0.8), 2.0)
	# Curva de nivel tracejada no miolo.
	var contour := PackedVector2Array()
	for p in shape:
		contour.append(c + (p - c) * 0.62)
	for i in range(0, contour.size(), 2):
		draw_line(contour[i], contour[(i + 1) % contour.size()], Color(UiTokens.INK, 0.25), 1.0)

	match biome:
		"hills":
			for off in [Vector2(-0.75, 0.35), Vector2(0.55, 0.45), Vector2(-0.1, -0.55)]:
				_hill(c + off * radius, radius * 0.24)
		"forest":
			for i in range(14):
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.2, 0.75) * radius
				_tree(c + Vector2(cos(a), sin(a) * 0.7) * d, radius * 0.08)
		"craters":
			for i in range(6):
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.25, 0.7) * radius
				var cc := c + Vector2(cos(a), sin(a) * 0.7) * d
				var cr := rng.randf_range(0.07, 0.13) * radius
				draw_arc(cc, cr, 0, TAU, 14, Color(UiTokens.INK, 0.6), 1.5)
				draw_arc(
					cc + Vector2(1, 1),
					cr * 0.6,
					PI * 0.1,
					PI * 0.9,
					8,
					Color(UiTokens.INK, 0.4),
					1.0
				)
		"road":
			var a := c + Vector2(-radius * 0.85, radius * 0.25)
			var b := c + Vector2(radius * 0.85, -radius * 0.2)
			var n := 12
			for i in range(0, n, 2):
				draw_line(
					a.lerp(b, float(i) / n),
					a.lerp(b, float(i + 1) / n),
					Color(UiTokens.INK, 0.7),
					2.0
				)
			for off in [Vector2(-0.3, -0.5), Vector2(0.4, 0.45)]:
				_hill(c + off * radius, radius * 0.18)


func _hill(p: Vector2, r: float) -> void:
	# Morro arredondado (meia parabola), como as montanhas da arena.
	var pts := PackedVector2Array()
	for i in range(13):
		var t := -1.0 + 2.0 * i / 12.0
		pts.append(p + Vector2(t * r, -(1.0 - t * t) * r * 1.1))
	draw_polyline(pts, Color(UiTokens.INK, 0.7), 2.0)


func _tree(p: Vector2, r: float) -> void:
	draw_line(p, p + Vector2(0, r * 1.6), Color(UiTokens.INK, 0.7), 1.5)
	draw_circle(p, r, Color(UiTokens.MAP_TREE, 0.9), true, -1.0, false)
	draw_arc(p, r, 0, TAU, 10, Color(UiTokens.INK, 0.75), 1.2)


# ═════════════════════════════════════════════════════════════════════
#  ROTAS, ROSA DOS VENTOS, TEXTO
# ═════════════════════════════════════════════════════════════════════


## Rota entre bases consecutivas desenhada como parabola (bezier quadratica com
## o ponto de controle acima): a campanha inteira e uma sequencia de tiros.
func _draw_routes() -> void:
	for i in range(ISLANDS.size() - 1):
		var a := grid_to_screen(ISLANDS[i].grid)
		var b := grid_to_screen(ISLANDS[i + 1].grid)
		var lift := _cell * 1.6 + a.distance_to(b) * 0.12
		var ctrl := (a + b) * 0.5 + Vector2(0, -lift)
		var done: bool = done_routes[i] if i < done_routes.size() else false
		var col := UiTokens.MAP_ROUTE_DONE if done else UiTokens.MAP_ROUTE
		var steps := 40
		var prev := a
		for s in range(1, steps + 1):
			var t := float(s) / steps
			var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
			if t > 0.18 and t < 0.84 and s % 2 == 0:
				draw_line(prev, p, col, 3.0)
			prev = p
		# Ponta de seta perto do destino.
		var t1 := 0.84
		var tip := a.lerp(ctrl, t1).lerp(ctrl.lerp(b, t1), t1)
		var t0 := 0.8
		var back := a.lerp(ctrl, t0).lerp(ctrl.lerp(b, t0), t0)
		var d := (tip - back).normalized()
		draw_colored_polygon(
			PackedVector2Array(
				[tip + d * 6, tip - d * 8 + d.orthogonal() * 7, tip - d * 8 - d.orthogonal() * 7]
			),
			col
		)


func _draw_compass(c: Vector2, r: float) -> void:
	var ink := Color(UiTokens.INK, 0.75)
	for k in range(8):
		var a := -PI / 2.0 + k * PI / 4.0
		var long := r if k % 2 == 0 else r * 0.55
		var tip := c + Vector2(cos(a), sin(a)) * long
		var side := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * r * 0.12
		var fill := UiTokens.PAPER_DARK if k % 2 == 0 else UiTokens.PAPER
		draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]), fill)
		draw_polyline(PackedVector2Array([c + side, tip, c - side]), ink, 1.5)
	draw_arc(c, r * 0.35, 0, TAU, 24, ink, 1.5)
	_ink_text(c + Vector2(-6, -r - 6), "N", UiTokens.FONT_MD, 0.9, false)


func _ink_text(at: Vector2, text: String, size_px: int, alpha: float, centered: bool) -> void:
	var pos := at
	var font := _title_font if size_px >= UiTokens.FONT_MD and text.length() > 3 else _font
	if centered:
		pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(UiTokens.INK, alpha))
