extends Node2D
## Estrago progressivo do castelo: rachaduras, fumaca e, no fim, fogo.
##
## Le meta "hp"/"max_hp" do castelo (pai). Cada acerto escurece o sprite (por
## self_modulate, para nao brigar com o flash branco, que usa modulate) e soma
## rachaduras e colunas de fumaca: a crianca ve o quanto falta sem ler numero.

var _t := 0.0
var _cracks: Array = []


func _ready() -> void:
	z_index = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(8):
		var start := Vector2(rng.randf_range(-130, 130), rng.randf_range(-40, 50))
		var pts := PackedVector2Array([start])
		for k in range(4):
			start += Vector2(rng.randf_range(-10, 10), rng.randf_range(6, 14))
			pts.append(start)
		_cracks.append(pts)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var host := get_parent()
	if host == null or not host.has_meta("hp"):
		return
	var max_hp: int = host.get_meta("max_hp", 3)
	var lost: int = max_hp - int(host.get_meta("hp", max_hp))
	var body := host.get_node_or_null("Body") as CanvasItem
	if body:
		body.self_modulate = UiTokens.NO_TINT.darkened(0.18 * lost)
	if lost <= 0:
		return
	var px := float(UiTokens.PX)
	var n := mini(_cracks.size(), lost * 3)
	for i in range(n):
		draw_polyline(_cracks[i], UiTokens.NIGHT_950, px)
	# Colunas de fumaca subindo, uma por acerto.
	for k in range(lost):
		var base := Vector2(-80 + k * 70, -60)
		for j in range(5):
			var f := fposmod(_t * 0.5 + j * 0.2 + k * 0.13, 1.0)
			var p := base + Vector2(sin(f * 6.0 + k) * 8.0, -f * 90.0)
			draw_circle(
				p, 6.0 + f * 12.0, Color(UiTokens.SMOKE, 0.35 * (1.0 - f)), true, -1.0, false
			)
	if lost >= 2:
		var flick := 0.6 + 0.4 * sin(_t * 18.0)
		draw_circle(Vector2(30, -20), 10.0 * flick, Color(UiTokens.FIRE, 0.8), true, -1.0, false)
		draw_circle(Vector2(30, -22), 5.0 * flick, UiTokens.FIRE_HOT, true, -1.0, false)
