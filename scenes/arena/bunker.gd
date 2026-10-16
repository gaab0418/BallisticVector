extends Node2D
## Bunker enterrado: cupula de concreto com seteira e sacos de areia.
##
## So quebra com tiro caindo de cima (a arena confere o angulo de descida da
## bala no acerto). Tiro rasante ricocheteia -- e a crianca descobre que, para
## cair "de cima", a parabola precisa ser alta e fechada.

## Descida minima, em graus abaixo da horizontal, para o tiro furar o concreto.
const MIN_DESCENT_DEG := 40.0
const W := 74.0
const H := 34.0


func _ready() -> void:
	set_meta("hp", 2)
	set_meta("max_hp", 2)
	set_meta("bunker", true)
	z_index = 1


func _draw() -> void:
	var px := float(UiTokens.PX)
	var base := Vector2(0, 14)
	# Sacos de areia na frente.
	for i in range(5):
		var x := -W * 0.6 + i * W * 0.3
		draw_rect(Rect2(Vector2(x - 12, base.y - 10), Vector2(24, 12)), UiTokens.EARTH_DARK)
		draw_rect(Rect2(Vector2(x - 10, base.y - 9), Vector2(20, 9)), UiTokens.EARTH_LIGHT)
	# Cupula.
	var dome := PackedVector2Array()
	for i in range(17):
		var a := PI + PI * i / 16.0
		dome.append(base + Vector2(cos(a) * W * 0.5, sin(a) * H))
	draw_colored_polygon(dome, UiTokens.ROCK)
	var top := PackedVector2Array()
	for i in range(9):
		var a := PI + PI * 0.5 * i / 8.0
		top.append(base + Vector2(cos(a) * W * 0.5, sin(a) * H))
	top.append(base)
	draw_colored_polygon(top, UiTokens.ROCK_LIGHT)
	var outline := dome.duplicate()
	draw_polyline(outline, UiTokens.NIGHT_950, px * 2)
	# Seteira escura e marcas de concreto.
	draw_rect(Rect2(base + Vector2(-16, -H * 0.55), Vector2(32, 6)), UiTokens.NIGHT_950)
	draw_line(
		base + Vector2(-W * 0.25, -H * 0.85),
		base + Vector2(-W * 0.18, -H * 0.6),
		UiTokens.ROCK_DARK,
		px
	)
	draw_line(
		base + Vector2(W * 0.2, -H * 0.8),
		base + Vector2(W * 0.28, -H * 0.5),
		UiTokens.ROCK_DARK,
		px
	)
