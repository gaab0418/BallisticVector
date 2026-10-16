extends Node2D
## Replay do tiro que derrubou o ultimo inimigo: a curva se desenha de novo,
## devagar, com o vertice e a equacao escritos, antes da tela de resultado.

const DURATION := 1.8

var shot: Dictionary = {}
## Onde a bala acertou (m): a curva para ali, nao no chao.
var end_x := NAN
var _t := 0.0
var _font: Font


func _ready() -> void:
	z_index = 4
	_font = UiTheme.body_font(UiTokens.WEIGHT_BOLD)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if shot.is_empty():
		return
	var x0: float = shot.x_tank
	var x1 := end_x
	if is_nan(x1):
		x1 = Ballistics.root(shot)
	if is_nan(x1):
		return
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var pts := PackedVector2Array()
	var steps := 80
	for i in range(steps + 1):
		var x := lerpf(x0, x1, k * i / steps)
		pts.append(Ballistics.point_px(shot, x))
	draw_polyline(pts, UiTokens.AIM_OUTLINE, 8.0)
	draw_polyline(pts, UiTokens.GOLD, 4.0)
	var head := pts[pts.size() - 1]
	draw_circle(head, 6.0, UiTokens.BRASS_LIGHT, true, -1.0, false)
	if Ballistics.has_arc(shot) and Ballistics.vertex(shot).x <= lerpf(x0, x1, k):
		var v := Ballistics.vertex(shot)
		var vp := Ballistics.point_px(shot, v.x)
		UiIcon.paint(self, "vertex", Rect2(vp - Vector2(12, 12), Vector2(24, 24)), UiTokens.GOLD)
	var eq := "Tiro da vitória: y = %s %s %s" % [
		Ballistics.term(shot.a, 3, "x²", true), Ballistics.term(shot.b, 2, "x"), Ballistics.term(shot.c, 2, "")
	]
	# A direita: a esquerda e o lugar do balao da Ada.
	var at := Vector2(1260.0 - _font.get_string_size(eq, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_LG).x, 186.0)
	var alpha := clampf(_t * 2.0, 0.0, 1.0)
	draw_string_outline(_font, at, eq, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_LG, 8, Color(UiTokens.TEXT_OUTLINE, alpha))
	draw_string(_font, at, eq, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_LG, Color(UiTokens.GOLD, alpha))
