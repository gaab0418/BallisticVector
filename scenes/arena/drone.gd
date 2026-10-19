extends Node2D
## Drone da Base Foxtrot: voa em linha reta pela rota y = m x + n, da direita
## para o tanque. Se chegar, bate no tanque e volta para o comeco da rota.
## Para acertar, a bala tem que estar no ponto onde a parabola cruza a reta
## no mesmo instante que ele (a trajetoria mostra quando atirar).
##
## Segue o contrato dos inimigos com a arena: take_damage e on_enemy_destroyed.

## Velocidade horizontal, px/s. A trajetoria usa o mesmo valor para a dica.
const SPEED := 46.0
const START_X := 1330.0
const DAMAGE := 10

var route := Vector2(0.0, 5.0)
var player_ref: Node2D
var hp := 1
## Distancia extra antes de entrar na tela, para os drones virem em fila.
var delay_px := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = 2
	set_meta("drone", true)
	position = _point(START_X + delay_px)


## Ponto da rota no x de tela `x_px`.
func _point(x_px: float) -> Vector2:
	var xm := Ballistics.to_m(x_px - Campaign.ORIGIN_X)
	return Vector2(x_px, Campaign.GROUND_Y - Ballistics.to_px(route.x * xm + route.y))


func _process(delta: float) -> void:
	_t += delta
	position = _point(position.x - SPEED * delta)
	if (
		player_ref
		and is_instance_valid(player_ref)
		and position.x < player_ref.global_position.x + 60.0
	):
		var arena := get_parent()
		if arena.has_method("on_player_hit"):
			arena.on_player_hit(DAMAGE)
		position = _point(START_X)
	queue_redraw()


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		var arena = get_parent()
		if arena and arena.has_method("on_enemy_destroyed"):
			arena.on_enemy_destroyed(self)
		queue_free()


func _draw() -> void:
	# Nariz no -x: com a rotacao da reta na tela, aponta para onde ele voa.
	draw_set_transform(Vector2.ZERO, -atan(route.x), Vector2.ONE)
	var flame := 6.0 + sin(_t * 30.0) * 2.0
	draw_rect(Rect2(14, -3, flame, 6), UiTokens.EDITABLE)
	draw_rect(Rect2(-16, -6, 30, 12), UiTokens.NIGHT_950)
	draw_rect(Rect2(-14, -4, 26, 8), UiTokens.ENEMY_TANK_TINT)
	draw_rect(Rect2(-20, -3, 6, 6), UiTokens.DANGER)
	draw_rect(Rect2(6, -12, 6, 8), UiTokens.NIGHT_950)
	draw_rect(Rect2(6, 4, 6, 8), UiTokens.NIGHT_950)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
