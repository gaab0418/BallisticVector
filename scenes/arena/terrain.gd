extends Node2D
## Chao da arena: a faixa de terra onde tanque e castelo se apoiam. Tambem e
## obstaculo: a arena registra collision_polygon() e a bala para no chao.

const WIDTH := 1280.0
const BOTTOM := 740.0

var theme_colors: Dictionary = UiTokens.WORLD_EARTH
var ground_y := 652.0
var _seed := 1


func setup(world: Dictionary, y: float, seed_value: int) -> void:
	theme_colors = world
	ground_y = y
	_seed = seed_value
	queue_redraw()


## Poligono de colisao do chao, em coordenadas globais.
func collision_polygon() -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(-60, ground_y),
			Vector2(WIDTH + 60, ground_y),
			Vector2(WIDTH + 60, BOTTOM + 60),
			Vector2(-60, BOTTOM + 60),
		]
	)


func _draw() -> void:
	var px := float(UiTokens.PX)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed

	draw_rect(Rect2(0, ground_y, WIDTH, BOTTOM - ground_y), theme_colors.ground)
	# Camada funda mais escura, para dar profundidade.
	draw_rect(Rect2(0, ground_y + 34, WIDTH, BOTTOM - ground_y), theme_colors.ground_dark)
	for x in range(0, int(WIDTH), int(px * 6)):
		var h := px * rng.randi_range(0, 3)
		draw_rect(Rect2(x, ground_y + 30 - h, px * 6, h + px), theme_colors.ground_dark)

	# Pedrinhas e graos.
	for i in range(180):
		var p := Vector2(rng.randf_range(0, WIDTH), rng.randf_range(ground_y + 8, BOTTOM))
		var s := px * (2.0 if rng.randf() < 0.2 else 1.0)
		var col: Color = theme_colors.speck if rng.randf() < 0.6 else theme_colors.ground_dark
		draw_rect(Rect2(p.snapped(Vector2(px, px)), Vector2(s, s)), col)

	# Borda de cima: faixa clara com tufos irregulares.
	draw_rect(Rect2(0, ground_y, WIDTH, px * 3), theme_colors.lip)
	draw_rect(Rect2(0, ground_y + px * 3, WIDTH, px), theme_colors.lip_dark)
	for x in range(0, int(WIDTH), int(px * 2)):
		var r := rng.randf()
		if r < 0.35:
			draw_rect(Rect2(x, ground_y - px * 2, px * 2, px * 2), theme_colors.lip)
		elif r < 0.45:
			draw_rect(Rect2(x, ground_y - px * 4, px, px * 4), theme_colors.lip_dark)
