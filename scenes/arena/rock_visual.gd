extends Node2D
## Visual de um obstaculo, desenhado a partir do CollisionPolygon2D irmao: o que
## se ve e exatamente o que a bala e a mira enxergam.
##
## Luz vindo da esquerda: a metade a esquerda do pico e mais clara, a direita
## mais escura, com estratos horizontais e contorno escuro.

var rock_colors: Array = UiTokens.WORLD_EARTH.rock
var _poly := PackedVector2Array()


func setup(colors: Array) -> void:
	rock_colors = colors
	var col := get_parent().get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if col:
		_poly = col.polygon
	queue_redraw()


func _draw() -> void:
	if _poly.size() < 3:
		return
	var px := float(UiTokens.PX)
	var light: Color = rock_colors[0]
	var mid: Color = rock_colors[1]
	var dark: Color = rock_colors[2]

	draw_colored_polygon(_poly, mid)

	# Face iluminada: o poligono cortado pelo semiplano a esquerda do pico.
	var apex := _poly[0]
	for p in _poly:
		if p.y < apex.y:
			apex = p
	var left_half := PackedVector2Array(
		[Vector2(-2000, -2000), Vector2(apex.x, -2000), Vector2(apex.x, 2000), Vector2(-2000, 2000)]
	)
	for piece in Geometry2D.intersect_polygons(_poly, left_half):
		draw_colored_polygon(piece, light.lerp(mid, 0.35))
	var right_half := PackedVector2Array(
		[
			Vector2(apex.x + 18, -2000),
			Vector2(2000, -2000),
			Vector2(2000, 2000),
			Vector2(apex.x + 18, 2000)
		]
	)
	for piece in Geometry2D.intersect_polygons(_poly, right_half):
		draw_colored_polygon(piece, dark.lerp(mid, 0.25))

	# Estratos: linhas horizontais tracejadas, recortadas pelo poligono.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(apex.x * 13.0 + apex.y * 7.0))
	var y := apex.y + 22.0
	while y < 0.0:
		var x0 := -400.0
		while x0 < 400.0:
			var seg_len := rng.randf_range(10, 34)
			var seg := PackedVector2Array([Vector2(x0, y), Vector2(x0 + seg_len, y)])
			for cut in Geometry2D.intersect_polyline_with_polygon(seg, _poly):
				draw_polyline(cut, Color(dark, 0.55), px)
			x0 += seg_len + rng.randf_range(8, 26)
		y += rng.randf_range(16, 26)

	# Graos e pedras soltas.
	var bb := _bounds()
	for i in range(int(bb.get_area() / 900.0)):
		var p := Vector2(
			rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y)
		)
		if Geometry2D.is_point_in_polygon(p, _poly):
			var col := light if rng.randf() < 0.4 else dark
			draw_rect(Rect2(p.snapped(Vector2(px, px)), Vector2(px * 2, px * 2)), Color(col, 0.6))

	# Contorno escuro, fechado.
	var outline := _poly.duplicate()
	outline.append(_poly[0])
	draw_polyline(outline, UiTokens.NIGHT_950, px * 2)
	# Brilho na aresta do lado da luz.
	draw_line(apex, apex + Vector2(-8, 18), light, px * 2)


func _bounds() -> Rect2:
	var r := Rect2(_poly[0], Vector2.ZERO)
	for p in _poly:
		r = r.expand(p)
	return r
