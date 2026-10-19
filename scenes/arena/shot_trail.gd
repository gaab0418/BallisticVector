extends Node2D
## Rastro da bala do jogador, no estilo escolhido na Oficina. Segue o alvo em
## coordenadas globais e, quando a bala some, se desfaz aos poucos.

const LENGTH := 26
const FADE := 0.45

var target: Node2D
var style := "line"
var color := Color.WHITE
var _pts: Array = []
var _fade := 1.0
var _t := 0.0


func _ready() -> void:
	top_level = true
	z_index = 0


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(target):
		_pts.append(target.global_position)
		if _pts.size() > LENGTH:
			_pts.pop_front()
	else:
		_fade -= delta / FADE
		if _fade <= 0.0:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var n := _pts.size()
	for i in range(1, n):
		var k := float(i) / n
		var a: Vector2 = _pts[i - 1]
		var b: Vector2 = _pts[i]
		var alpha := k * _fade
		match style:
			"dots":
				if i % 2 == 0:
					draw_circle(b, 1.5 + 2.0 * k, Color(color, alpha), true, -1.0, false)
			"fire":
				var hot := UiTokens.FIRE_HOT.lerp(color, 1.0 - k)
				draw_line(a, b, Color(hot, alpha), 2.0 + 5.0 * k)
			"stars":
				if i % 4 == 0:
					var s := 4.0 + 6.0 * k
					UiIcon.paint(
						self,
						"star",
						Rect2(b - Vector2(s, s) * 0.5, Vector2(s, s)),
						Color(color, alpha),
						false
					)
				draw_line(a, b, Color(color, alpha * 0.4), 1.5)
			"rainbow":
				var hue := fposmod(k * 0.8 + _t * 0.5, 1.0)
				draw_line(a, b, Color.from_hsv(hue, 0.75, 1.0, alpha), 2.0 + 4.0 * k)
			_:
				draw_line(a, b, Color(color, alpha * 0.8), 1.5 + 4.0 * k)
