class_name WarTable
extends Control
## O mapa de guerra: um pergaminho sobre a mesa de comando, desenhado em codigo.
##
## O mapa e um plano cartesiano: grade, eixos x e y numerados, cada base numa
## ilha com coordenadas, e rotas entre as bases em arco de parabola. Tudo e
## calculado a partir do tamanho atual.
##
## O plano vai de x = 0 a x = 40 e a janela mostra 20 de cada vez (tres bases
## por tela). A camada do mapa (map_layer) e recortada no pergaminho, entao o
## que fica fora da janela some.

## Largura visivel da janela (em unidades do plano) e largura total do plano.
const GRID_W := 20
const WORLD_W := 40
const PAGES := 2
const GRID_H := 9
const PAD := 44.0
const ISLAND_R := 1.75

## Ilhas na ordem dos capitulos, tres por tela. biome: hills (Alpha), forest
## (Bravo), craters (Charlie), road (Delta), balloons (Echo), inverted (bonus).
const ISLANDS := [
	{"grid": Vector2(3.6, 5.8), "biome": "hills"},
	{"grid": Vector2(10, 2.7), "biome": "forest"},
	{"grid": Vector2(16.4, 6.0), "biome": "craters"},
	{"grid": Vector2(23.6, 2.8), "biome": "road"},
	{"grid": Vector2(30, 6.1), "biome": "balloons"},
	{"grid": Vector2(36.4, 2.9), "biome": "inverted"},
]
## Ilhotas decorativas, sem base.
const ISLETS := [
	Vector2(6.8, 1.4),
	Vector2(13.0, 8.2),
	Vector2(1.2, 2.0),
	Vector2(19.9, 1.6),
	Vector2(26.6, 8.0),
	Vector2(33.4, 1.4),
	Vector2(39.4, 5.4),
]
## Nomes dos mares, um por tela.
const SEAS := [
	{"grid": Vector2(9.6, 7.9), "name": "Mar das Parábolas"},
	{"grid": Vector2(30.2, 1.3), "name": "Mar do Vértice"},
]
## Rosa dos ventos: fixa na janela (canto superior direito), nao desliza.
const COMPASS_VIEW := Vector2(19.0, 8.0)

var top_margin := 70.0
var bottom_margin := 86.0
## Trechos de rota ja percorridos (base anterior conquistada).
var done_routes: Array = [false, false, false, false, false]
## Por ilha: {"cleared": n, "total": n, "stars": [..], "locked": bool}.
var progress: Array = []
var _boat_route := -1
var _boat_t := 0.0
## Inicio da janela no plano (0 = primeira tela, GRID_W = segunda).
var view_x := 0.0
## Camada recortada no pergaminho onde o plano e desenhado (e as bases vivem).
var map_layer: Control
var _ci: CanvasItem = self
var _pan: Tween

## A janela andou (as bases precisam acompanhar).
signal view_changed

var _font: Font
var _title_font: Font
var _paper := Rect2()
var _origin := Vector2.ZERO
var _cell := 50.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.body_font()
	_title_font = UiTheme.title_font()
	map_layer = Control.new()
	map_layer.name = "MapLayer"
	map_layer.clip_contents = true
	map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_layer.draw.connect(_draw_map)
	add_child(map_layer)
	resized.connect(_layout)
	_layout()


## Tela (0 ou 1) onde fica a ilha `index`.
static func page_of(index: int) -> int:
	return floori(ISLANDS[index].grid.x / float(GRID_W))


func current_page() -> int:
	return roundi(view_x / float(GRID_W))


## Desliza a janela ate a tela `page`.
func show_page(page: int, animate: bool = true) -> void:
	var target := float(clampi(page, 0, PAGES - 1) * GRID_W)
	if _pan:
		_pan.kill()
	if not animate:
		_set_view(target)
		return
	_pan = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_pan.tween_method(_set_view, view_x, target, 0.7)


func _set_view(x: float) -> void:
	view_x = x
	map_layer.queue_redraw()
	queue_redraw()
	view_changed.emit()


func _layout() -> void:
	_paper = Rect2(Vector2(26, top_margin), size - Vector2(52, top_margin + bottom_margin))
	var plot := _paper.grow(-PAD)
	_cell = minf(plot.size.x / GRID_W, plot.size.y / GRID_H)
	var used := Vector2(GRID_W, GRID_H) * _cell
	_origin = Vector2(
		plot.position.x + (plot.size.x - used.x) * 0.5, plot.end.y - (plot.size.y - used.y) * 0.5
	)
	# A camada recortada cobre o miolo do pergaminho (sem a borda rasgada).
	var clip := _paper.grow(-10.0)
	map_layer.position = clip.position
	map_layer.size = clip.size
	queue_redraw()
	map_layer.queue_redraw()
	view_changed.emit()


## Ponto do plano cartesiano (x para a direita, y para cima) em pixels de tela.
func grid_to_screen(g: Vector2) -> Vector2:
	return _origin + Vector2(g.x - view_x, -g.y) * _cell


## O mesmo ponto nas coordenadas da camada recortada (onde as bases ficam).
func grid_to_layer(g: Vector2) -> Vector2:
	return grid_to_screen(g) - map_layer.position


## Retangulo da janela visivel do mapa, em pixels de tela.
func view_rect() -> Rect2:
	return Rect2(map_layer.position, map_layer.size)


func cell_size() -> float:
	return _cell


func _draw() -> void:
	_ci = self
	_draw_table()
	_draw_paper()
	_draw_page_dots()


## Tudo que desliza com a janela, desenhado na camada recortada. As funcoes
## trabalham em pixels de tela; o transform converte para a camada.
func _draw_map() -> void:
	_ci = map_layer
	map_layer.draw_set_transform(-map_layer.position, 0.0, Vector2.ONE)
	_draw_sea()
	_draw_grid()
	for p in ISLETS:
		_draw_island(grid_to_screen(p), _cell * 0.55, int(p.x * 13 + p.y * 7), "")
	for i in range(ISLANDS.size()):
		var isl: Dictionary = ISLANDS[i]
		_draw_island(grid_to_screen(isl.grid), _cell * ISLAND_R, 31 + i * 17, isl.biome)
	_draw_routes()
	_draw_stage_dots()
	_draw_fog()
	_draw_boat()
	for sea in SEAS:
		_ink_text(grid_to_screen(sea.grid), sea.name, UiTokens.FONT_MD, 0.55, true)
	_draw_compass(grid_to_screen(Vector2(view_x, 0) + COMPASS_VIEW), _cell * 0.8)
	map_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ci = self


## Bolinhas na borda de baixo do pergaminho: em qual tela do mapa estamos.
func _draw_page_dots() -> void:
	var c := Vector2(_paper.get_center().x, _paper.end.y - 14.0)
	for i in range(PAGES):
		var p := c + Vector2((i - (PAGES - 1) * 0.5) * 22.0, 0)
		var on := i == current_page()
		draw_circle(p, 6.0, UiTokens.INK if on else UiTokens.PAPER, true, -1.0, false)
		draw_arc(p, 6.0, 0, TAU, 14, UiTokens.INK, 1.5)


## Barquinho percorrendo a rota que leva a proxima base (chamado ao voltar de
## uma base conquistada).
func animate_boat(route_index: int) -> void:
	if route_index < 0 or route_index >= ISLANDS.size() - 1:
		return
	_boat_route = route_index
	_boat_t = 0.0


func _process(delta: float) -> void:
	if _boat_route < 0:
		return
	_boat_t += delta / 3.2
	if _boat_t >= 1.0:
		_boat_route = -1
	map_layer.queue_redraw()


# ═════════════════════════════════════════════════════════════════════
#  MESA E PERGAMINHO
# ═════════════════════════════════════════════════════════════════════


## Tampo de madeira em tabuas horizontais, com veios.
func _draw_table() -> void:
	_ci.draw_rect(Rect2(Vector2.ZERO, size), UiTokens.WOOD_DARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var plank := 44.0
	var y := 0.0
	var i := 0
	while y < size.y:
		var col := UiTokens.WOOD if i % 2 == 0 else UiTokens.WOOD.darkened(0.08)
		_ci.draw_rect(Rect2(0, y, size.x, plank - 2), col)
		for k in range(10):
			var gx := rng.randf_range(0, size.x)
			var gy := y + rng.randf_range(6, plank - 8)
			_ci.draw_line(
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
	_ci.draw_colored_polygon(shadow, UiTokens.SHADOW)
	_ci.draw_colored_polygon(edge, UiTokens.PAPER)
	# Borda escurecida em aneis: o papel envelhece de fora para dentro.
	for k in range(6):
		var ring := PackedVector2Array()
		var inset := 4.0 + k * 5.0
		var r := _paper.grow(-inset)
		for p in edge:
			ring.append(p.clamp(r.position, r.end))
		ring.append(ring[0])
		_ci.draw_polyline(ring, Color(UiTokens.PAPER_DARK, 0.22 - k * 0.03), 6.0)
	for k in range(7):
		var c := Vector2(
			rng.randf_range(_paper.position.x + 60, _paper.end.x - 60),
			rng.randf_range(_paper.position.y + 40, _paper.end.y - 40)
		)
		_ci.draw_circle(
			c, rng.randf_range(18, 46), Color(UiTokens.PAPER_DARK, 0.12), true, -1.0, false
		)
	var outline := edge.duplicate()
	outline.append(edge[0])
	_ci.draw_polyline(outline, Color(UiTokens.INK, 0.6), 2.0)


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
	# O plano inteiro, para a pontinha da outra tela aparecer na borda com o mesmo mar.
	var a := grid_to_screen(Vector2(-2, GRID_H))
	var b := grid_to_screen(Vector2(WORLD_W + 2, 0))
	_ci.draw_rect(Rect2(a, b - a), UiTokens.MAP_SEA)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in range(140):
		var g := Vector2(rng.randf_range(0.5, WORLD_W - 0.5), rng.randf_range(0.4, GRID_H - 0.4))
		if _near_island(g):
			continue
		var p := grid_to_screen(g)
		var w := _cell * 0.18
		var ink := Color(UiTokens.INK, 0.28)
		_ci.draw_arc(p, w, PI * 1.15, PI * 1.85, 6, ink, 1.2)
		_ci.draw_arc(p + Vector2(w * 1.6, 0), w, PI * 1.15, PI * 1.85, 6, ink, 1.2)


func _near_island(g: Vector2) -> bool:
	for isl in ISLANDS:
		if g.distance_to(isl.grid) < ISLAND_R * 1.35:
			return true
	for p in ISLETS:
		if g.distance_to(p) < 1.0:
			return true
	for sea in SEAS:
		if absf(g.y - sea.grid.y) < 0.6 and absf(g.x - sea.grid.x) < 3.0:
			return true
	return false


# ═════════════════════════════════════════════════════════════════════
#  PLANO CARTESIANO
# ═════════════════════════════════════════════════════════════════════


func _draw_grid() -> void:
	var faint := Color(UiTokens.INK, 0.1)
	for gx in range(WORLD_W + 1):
		var top := grid_to_screen(Vector2(gx, GRID_H))
		_ci.draw_line(grid_to_screen(Vector2(gx, 0)), top, faint, 1.0)
	for gy in range(GRID_H + 1):
		var right := grid_to_screen(Vector2(WORLD_W, gy))
		_ci.draw_line(grid_to_screen(Vector2(0, gy)), right, faint, 1.0)

	# Eixos com seta, como no caderno.
	var ink := Color(UiTokens.INK, 0.75)
	var o := grid_to_screen(Vector2.ZERO)
	var xe := grid_to_screen(Vector2(WORLD_W + 0.4, 0))
	var ye := grid_to_screen(Vector2(0, GRID_H + 0.4))
	_ci.draw_line(o, xe, ink, 2.0)
	_ci.draw_line(o, ye, ink, 2.0)
	_ci.draw_colored_polygon(
		PackedVector2Array([xe, xe + Vector2(-10, -5), xe + Vector2(-10, 5)]), ink
	)
	_ci.draw_colored_polygon(
		PackedVector2Array([ye, ye + Vector2(-5, 10), ye + Vector2(5, 10)]), ink
	)
	_ink_text(xe + Vector2(-6, 22), "x", UiTokens.FONT_MD, 0.85, false)
	_ink_text(ye + Vector2(-22, 6), "y", UiTokens.FONT_MD, 0.85, false)

	for gx in range(0, WORLD_W + 1, 2):
		var p := grid_to_screen(Vector2(gx, 0))
		_ci.draw_line(p, p + Vector2(0, 5), ink, 1.0)
		_ink_text(p + Vector2(-4, 20), str(gx), UiTokens.FONT_XS, 0.7, false)
	# Numeros de y presos a borda esquerda da janela: na segunda tela o eixo
	# x = 0 ficou para tras.
	var left := view_x
	for gy in range(1, GRID_H + 1):
		var p := grid_to_screen(Vector2(left, gy))
		_ci.draw_line(p, p + Vector2(-5, 0), ink, 1.0)
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
		_ci.draw_polyline(ripple, Color(UiTokens.INK, 0.14 if w > 10.0 else 0.25), 1.0)

	_ci.draw_colored_polygon(shape, UiTokens.MAP_LAND)
	var coast := shape.duplicate()
	coast.append(shape[0])
	_ci.draw_polyline(coast, Color(UiTokens.INK, 0.8), 2.0)
	# Curva de nivel tracejada no miolo.
	var contour := PackedVector2Array()
	for p in shape:
		contour.append(c + (p - c) * 0.62)
	for i in range(0, contour.size(), 2):
		_ci.draw_line(contour[i], contour[(i + 1) % contour.size()], Color(UiTokens.INK, 0.25), 1.0)

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
				_ci.draw_arc(cc, cr, 0, TAU, 14, Color(UiTokens.INK, 0.6), 1.5)
				_ci.draw_arc(
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
				_ci.draw_line(
					a.lerp(b, float(i) / n),
					a.lerp(b, float(i + 1) / n),
					Color(UiTokens.INK, 0.7),
					2.0
				)
			for off in [Vector2(-0.3, -0.5), Vector2(0.4, 0.45)]:
				_hill(c + off * radius, radius * 0.18)
		"balloons":
			# Baloes presos ao chao em alturas diferentes, como na Base Echo.
			for k in range(3):
				var bp := c + Vector2((-0.55 + k * 0.5) * radius, (-0.15 - 0.12 * k) * radius)
				var foot := bp + Vector2(0, radius * 0.45)
				_ci.draw_line(bp, foot, Color(UiTokens.INK, 0.6), 1.0)
				_ci.draw_circle(
					bp, radius * 0.11, Color(UiTokens.BALLOON_A, 0.75), true, -1.0, false
				)
				_ci.draw_arc(bp, radius * 0.11, 0, TAU, 12, Color(UiTokens.INK, 0.8), 1.2)
			_ci.draw_line(
				c + Vector2(-radius * 0.8, -radius * 0.42),
				c + Vector2(radius * 0.8, -radius * 0.42),
				Color(UiTokens.EDITABLE_ON_PAPER, 0.6),
				1.5
			)
		"inverted":
			# Um "sorriso": a parabola de boca para cima da ilha bonus.
			var pts := PackedVector2Array()
			for i in range(15):
				var t := -1.0 + 2.0 * i / 14.0
				pts.append(c + Vector2(t * radius * 0.55, (t * t - 0.6) * radius * 0.45))
			_ci.draw_polyline(pts, Color(UiTokens.INK, 0.75), 2.0)


func _hill(p: Vector2, r: float) -> void:
	# Morro arredondado (meia parabola), como as montanhas da arena.
	var pts := PackedVector2Array()
	for i in range(13):
		var t := -1.0 + 2.0 * i / 12.0
		pts.append(p + Vector2(t * r, -(1.0 - t * t) * r * 1.1))
	_ci.draw_polyline(pts, Color(UiTokens.INK, 0.7), 2.0)


func _tree(p: Vector2, r: float) -> void:
	_ci.draw_line(p, p + Vector2(0, r * 1.6), Color(UiTokens.INK, 0.7), 1.5)
	_ci.draw_circle(p, r, Color(UiTokens.MAP_TREE, 0.9), true, -1.0, false)
	_ci.draw_arc(p, r, 0, TAU, 10, Color(UiTokens.INK, 0.75), 1.2)


# ═════════════════════════════════════════════════════════════════════
#  ROTAS, ROSA DOS VENTOS, TEXTO
# ═════════════════════════════════════════════════════════════════════


## Rota entre bases consecutivas: bezier quadratica com o ponto de controle
## acima, ou seja, um arco de parabola.
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
				_ci.draw_line(prev, p, col, 3.0)
			prev = p
		# Ponta de seta perto do destino.
		var t1 := 0.84
		var tip := a.lerp(ctrl, t1).lerp(ctrl.lerp(b, t1), t1)
		var t0 := 0.8
		var back := a.lerp(ctrl, t0).lerp(ctrl.lerp(b, t0), t0)
		var d := (tip - back).normalized()
		_ci.draw_colored_polygon(
			PackedVector2Array(
				[tip + d * 6, tip - d * 8 + d.orthogonal() * 7, tip - d * 8 - d.orthogonal() * 7]
			),
			col
		)


## Tres (ou duas) bolinhas no alto de cada ilha, uma por fase: cheia em ambar
## quando ganhou estrela, cheia a tinta quando venceu, vazia quando falta.
func _draw_stage_dots() -> void:
	for i in range(mini(progress.size(), ISLANDS.size())):
		var info: Dictionary = progress[i]
		var total: int = info.total
		var c := grid_to_screen(ISLANDS[i].grid) + Vector2(_cell * 0.95, -_cell * 0.85)
		for k in range(total):
			var p := c + Vector2(k * 13.0, 0)
			var stars: int = info.stars[k] if k < info.stars.size() else 0
			_ci.draw_circle(p, 5.5, UiTokens.PAPER, true, -1.0, false)
			if stars > 0:
				_ci.draw_circle(p, 4.5, UiTokens.EDITABLE_ON_PAPER, true, -1.0, false)
			elif k < int(info.cleared):
				_ci.draw_circle(p, 4.5, Color(UiTokens.INK, 0.7), true, -1.0, false)
			_ci.draw_arc(p, 5.5, 0, TAU, 12, Color(UiTokens.INK, 0.8), 1.2)


## Nevoa sobre as ilhas ainda bloqueadas: nuvens de papel com contorno a tinta.
func _draw_fog() -> void:
	for i in range(mini(progress.size(), ISLANDS.size())):
		if not progress[i].locked:
			continue
		var c := grid_to_screen(ISLANDS[i].grid)
		var rng := RandomNumberGenerator.new()
		rng.seed = 101 + i
		for k in range(9):
			var off := Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.8, 0.8)) * _cell
			var r := rng.randf_range(0.45, 0.75) * _cell
			_ci.draw_circle(c + off, r, Color(UiTokens.PAPER, 0.82), true, -1.0, false)
			_ci.draw_arc(c + off, r, PI * 1.05, PI * 1.95, 10, Color(UiTokens.INK, 0.25), 1.2)


func _draw_boat() -> void:
	if _boat_route < 0:
		return
	var a := grid_to_screen(ISLANDS[_boat_route].grid)
	var b := grid_to_screen(ISLANDS[_boat_route + 1].grid)
	var ctrl := (a + b) * 0.5 + Vector2(0, -(_cell * 1.6 + a.distance_to(b) * 0.12))
	var t := clampf(0.15 + _boat_t * 0.7, 0.0, 1.0)
	var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
	var ink := Color(UiTokens.INK, 0.9)
	var hull := PackedVector2Array(
		[p + Vector2(-14, 0), p + Vector2(14, 0), p + Vector2(9, 7), p + Vector2(-9, 7)]
	)
	_ci.draw_colored_polygon(hull, UiTokens.WOOD)
	_ci.draw_polyline(hull, ink, 1.5)
	_ci.draw_line(p, p + Vector2(0, -22), ink, 1.5)
	var sail := PackedVector2Array([p + Vector2(1, -21), p + Vector2(13, -4), p + Vector2(1, -4)])
	_ci.draw_colored_polygon(sail, UiTokens.PAPER)
	_ci.draw_polyline(sail, ink, 1.2)


func _draw_compass(c: Vector2, r: float) -> void:
	var ink := Color(UiTokens.INK, 0.75)
	for k in range(8):
		var a := -PI / 2.0 + k * PI / 4.0
		var long := r if k % 2 == 0 else r * 0.55
		var tip := c + Vector2(cos(a), sin(a)) * long
		var side := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * r * 0.12
		var fill := UiTokens.PAPER_DARK if k % 2 == 0 else UiTokens.PAPER
		_ci.draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]), fill)
		_ci.draw_polyline(PackedVector2Array([c + side, tip, c - side]), ink, 1.5)
	_ci.draw_arc(c, r * 0.35, 0, TAU, 24, ink, 1.5)
	_ink_text(c + Vector2(-6, -r - 6), "N", UiTokens.FONT_MD, 0.9, false)


func _ink_text(at: Vector2, text: String, size_px: int, alpha: float, centered: bool) -> void:
	var pos := at
	var font := _title_font if size_px >= UiTokens.FONT_MD and text.length() > 3 else _font
	if centered:
		pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	_ci.draw_string(
		font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(UiTokens.INK, alpha)
	)
