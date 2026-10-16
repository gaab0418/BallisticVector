extends Node2D
## Bandeirinha na antena do tanque, escolhida na Oficina. O pano tremula e leva
## o icone do item (estrela, engrenagem, vertice...).

var icon := ""
var cloth := Color.WHITE
var _t := 0.0


func setup(flag: Dictionary) -> void:
	icon = flag.get("icon", "")
	cloth = Color(flag.get("color", "ffffff"))
	visible = icon != ""


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var px := float(UiTokens.PX)
	var top := Vector2(0, -20)
	draw_line(Vector2.ZERO, top, UiTokens.NIGHT_950, px)
	# Pano em faixas verticais que ondulam com fases diferentes: tremula.
	var w := 22.0
	var h := 14.0
	var cols := 6
	for i in range(cols):
		var x := top.x + i * w / cols
		var wave := sin(_t * 6.0 - i * 0.9) * 1.6 * (float(i) / cols)
		draw_rect(Rect2(Vector2(x, top.y + wave), Vector2(w / cols + 0.5, h)), cloth)
	var outline := PackedVector2Array([top, top + Vector2(w, 0), top + Vector2(w, h), top + Vector2(0, h), top])
	draw_polyline(outline, UiTokens.NIGHT_950, 1.0)
	var s := 10.0
	UiIcon.paint(self, icon, Rect2(top + Vector2((w - s) * 0.5, (h - s) * 0.5), Vector2(s, s)), UiTokens.TEXT_HOVER, false)
