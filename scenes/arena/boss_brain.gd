extends Node2D
## O chefe da ultima fase de cada base: o castelo ganha um nome e uma regra que
## pede a ideia do capitulo para ser vencida.
##
##   shield  -- (Alpha) cupula que so deixa passar bala caindo de cima: vertice alto
##   moving  -- (Bravo, Norte) anda numa faixa: a raiz tem que acompanhar
##   hopping -- (Delta) a cada acerto foge para outro ponto: ande com o tanque
##   gravity -- (Charlie) a cada acerto troca a gravidade do mundo
##   guarded -- (Echo, Foxtrot) escudo que so cai quando os outros inimigos caem

const SHIELD_R := 120.0
## Centro da cupula: a base do castelo fica 86 px abaixo da origem dele.
const SHIELD_C := Vector2(0, 82)

var data: Dictionary = {}
var arena: Node2D
var _spot := 0
var _dir := -1.0
var _hits := 0
var _t := 0.0
var _font: Font


func setup(host_arena: Node2D, chief: Dictionary) -> void:
	arena = host_arena
	data = chief
	name = "Brain"
	_font = UiTheme.body_font(UiTokens.WEIGHT_BOLD)
	z_index = 3


func kind() -> String:
	return data.get("kind", "")


func _process(delta: float) -> void:
	_t += delta
	var host := get_parent() as Node2D
	if kind() == "moving" and not arena.stage_cleared:
		var zone: Vector2 = data.get("zone", Vector2(host.position.x, host.position.x))
		host.position.x += _dir * float(data.get("speed", 20.0)) * delta
		if host.position.x < zone.x:
			host.position.x = zone.x
			_dir = 1.0
		elif host.position.x > zone.y:
			host.position.x = zone.y
			_dir = -1.0
	queue_redraw()


## Motivo para a bala nao causar dano ("" = passa). Chamado antes do dano.
func blocks(bullet: Node2D) -> String:
	match kind():
		"shield":
			if bullet == null:
				return ""
			var v: Vector2 = bullet.velocity
			var descent := rad_to_deg(atan2(v.y, absf(v.x)))
			var need: float = data.get("min_descent", 35.0)
			if descent < need:
				return "o escudo desviou! a bala caiu a %d°, precisa de %d°" % [maxi(0, roundi(descent)), roundi(need)]
		"guarded":
			if _guards_alive() > 0:
				return "escudo ligado! derrube os outros %d inimigos primeiro" % _guards_alive()
	return ""


## Depois de um acerto que causou dano.
func on_hit() -> void:
	_hits += 1
	match kind():
		"hopping":
			var spots: Array = data.get("spots", [])
			if spots.is_empty():
				return
			_spot = (_spot + 1) % spots.size()
			var host := get_parent() as Node2D
			var tw := host.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(host, "position:x", float(spots[_spot]), 0.6)
			arena.hud.show_toast("O castelo fugiu! Ande com o tanque e mire de novo.", UiTokens.EDITABLE)
		"gravity":
			var list: Array = data.get("list", [])
			if list.is_empty():
				return
			arena.set_world_gravity(float(list[_hits % list.size()]))


func _guards_alive() -> int:
	var n := 0
	for e in arena.active_enemies:
		if is_instance_valid(e) and e != get_parent():
			n += 1
	return n


func _shield_on() -> bool:
	return kind() == "shield" or (kind() == "guarded" and _guards_alive() > 0)


func _draw() -> void:
	if _shield_on():
		var a := 0.22 + 0.06 * sin(_t * 3.0)
		var col := UiTokens.CALCULATED if kind() == "shield" else UiTokens.DANGER
		draw_arc(SHIELD_C, SHIELD_R, PI, TAU, 40, Color(col, a + 0.35), 3.0)
		# So a metade de cima: a cupula se apoia no chao.
		var dome := PackedVector2Array()
		for i in range(41):
			dome.append(SHIELD_C + Vector2.from_angle(PI + PI * i / 40.0) * SHIELD_R)
		draw_colored_polygon(dome, Color(col, a * 0.35))
	var title := "CHEFE · " + str(data.get("name", ""))
	var size_px := UiTokens.FONT_SM
	var w := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var at := Vector2(-w * 0.5, -122)
	draw_string_outline(_font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, UiTokens.TEXT_OUTLINE_SIZE + 2, UiTokens.TEXT_OUTLINE)
	draw_string(_font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, UiTokens.GOLD)
