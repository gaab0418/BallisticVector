extends Control
class_name AmmoIcon

var ammo_color: Color = Color.WHITE


func _init(c: Color = Color.WHITE):
	ammo_color = c
	custom_minimum_size = Vector2(40, 40)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw():
	var w = size.x
	var h = size.y
	var cx = w / 2.0
	var cy = h / 2.0

	# Dimensões da bala
	var bullet_w = w * 0.4
	var bullet_h = h * 0.8
	var bx = cx - bullet_w / 2.0
	var by = cy - bullet_h / 2.0

	# Corpo da cápsula (latão/bronze)
	var brass = Color(0.8, 0.55, 0.2)
	var shadow = Color(0.5, 0.3, 0.1)
	draw_rect(Rect2(bx, by + bullet_h * 0.4, bullet_w, bullet_h * 0.5), brass)
	draw_rect(
		Rect2(bx + bullet_w * 0.7, by + bullet_h * 0.4, bullet_w * 0.3, bullet_h * 0.5), shadow
	)

	# Base da cápsula
	draw_rect(
		Rect2(bx - 2, by + bullet_h * 0.9, bullet_w + 4, bullet_h * 0.1), Color(0.6, 0.4, 0.15)
	)

	# Ponta da bala (usando a cor da munição)
	var tip_pts = PackedVector2Array(
		[
			Vector2(bx, by + bullet_h * 0.4),
			Vector2(bx + bullet_w, by + bullet_h * 0.4),
			Vector2(bx + bullet_w * 0.8, by + bullet_h * 0.1),
			Vector2(bx + bullet_w * 0.2, by + bullet_h * 0.1)
		]
	)
	draw_polygon(tip_pts, PackedColorArray([ammo_color, ammo_color, ammo_color, ammo_color]))

	var point_pts = PackedVector2Array(
		[
			Vector2(bx + bullet_w * 0.2, by + bullet_h * 0.1),
			Vector2(bx + bullet_w * 0.8, by + bullet_h * 0.1),
			Vector2(cx, by)
		]
	)
	draw_polygon(point_pts, PackedColorArray([ammo_color, ammo_color, ammo_color]))

	# Detalhes Steampunk (linhas transversais)
	draw_line(
		Vector2(bx, by + bullet_h * 0.6),
		Vector2(bx + bullet_w, by + bullet_h * 0.6),
		Color(0.4, 0.2, 0.1),
		2.0
	)
	draw_line(
		Vector2(bx, by + bullet_h * 0.8),
		Vector2(bx + bullet_w, by + bullet_h * 0.8),
		Color(0.4, 0.2, 0.1),
		2.0
	)
