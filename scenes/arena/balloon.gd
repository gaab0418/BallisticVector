extends Node2D
## Balao-alvo da Base Echo, amarrado ao chao por uma corda com a altura escrita
## ("5 m"), ligando o balao a linha y = h. Usa meta "hp" como o castelo, entao a
## arena trata o acerto pelo mesmo caminho.

const RADIUS := 18.0

var height_m := 5.0
var ground_y := 652.0
var color := UiTokens.BALLOON_A
var _t := 0.0
var _base_y := 0.0
var _font: Font


func _ready() -> void:
	set_meta("hp", 1)
	set_meta("max_hp", 1)
	set_meta("balloon", true)
	_base_y = position.y
	_t = randf() * TAU
	_font = UiTheme.body_font(UiTokens.WEIGHT_BOLD)
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	# Balanco leve: vivo, mas sem sair da altura que a corda promete.
	position.y = _base_y + sin(_t * 1.6) * 2.5
	queue_redraw()


func _draw() -> void:
	var px := float(UiTokens.PX)
	var rope_top := Vector2(0, RADIUS + 6)
	var rope_bottom := Vector2(sin(_t) * 3.0, ground_y - position.y)
	var ink := Color(UiTokens.INK, 0.8)
	var steps := 18
	for i in range(0, steps, 2):
		draw_line(
			rope_top.lerp(rope_bottom, float(i) / steps),
			rope_top.lerp(rope_bottom, float(i + 1) / steps),
			ink,
			px
		)
	var mid := rope_top.lerp(rope_bottom, 0.5) + Vector2(6, 0)
	var txt := Ballistics.fmt(height_m, 0) + " m"
	draw_string_outline(
		_font,
		mid,
		txt,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiTokens.FONT_XS,
		UiTokens.TEXT_OUTLINE_SIZE,
		UiTokens.TEXT_OUTLINE
	)
	draw_string(_font, mid, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_XS, UiTokens.EDITABLE)

	# Balao: contorno, corpo, gomo mais claro, brilho e no.
	draw_colored_polygon(_ellipse(RADIUS + px, RADIUS * 1.18 + px), UiTokens.NIGHT_950)
	draw_colored_polygon(_ellipse(RADIUS, RADIUS * 1.18), color)
	draw_colored_polygon(_ellipse(RADIUS * 0.45, RADIUS * 1.12), color.lightened(0.25))
	draw_rect(Rect2(Vector2(-RADIUS * 0.5, -RADIUS * 0.7), Vector2(px * 2, px * 4)), UiTokens.SHINE)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(-4, RADIUS * 1.15), Vector2(4, RADIUS * 1.15), Vector2(0, RADIUS * 1.15 + 7)]
		),
		color.darkened(0.3)
	)


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
