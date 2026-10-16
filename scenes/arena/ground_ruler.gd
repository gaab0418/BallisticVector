extends Node2D
## Regua em metros no chao da arena: uma fita metrica de papel com tinta.
##
## E o que torna a HUD conferivel. A crianca le "Alcance 23 m" no painel, ve a
## bandeira da raiz sobre a fita e confere o numero olhando a tela. Marca a cada
## metro, numero a cada cinco, zero no munhao do canhao.

const TAPE_H := 20.0
const WIDTH := 1280.0

var origin_x := 104.0
var ground_y := 652.0
## Faixa de movimento do tanque (fases da Base Delta), em px globais. x > y = sem faixa.
var move_zone := Vector2(1, 0)
var _font: Font


func setup(origin: float, y: float, zone: Vector2) -> void:
	origin_x = origin
	ground_y = y
	move_zone = zone
	_font = UiTheme.body_font(UiTokens.WEIGHT_BOLD)
	queue_redraw()


func _draw() -> void:
	var px := float(UiTokens.PX)
	var top := ground_y + px * 4
	var ppm := Ballistics.PX_PER_METER

	if move_zone.y > move_zone.x:
		_draw_move_zone()

	var x_start := origin_x
	draw_rect(Rect2(x_start - 6, top, WIDTH - x_start + 6, TAPE_H), UiTokens.RULER_TAPE)
	draw_rect(Rect2(x_start - 6, top + TAPE_H, WIDTH - x_start + 6, px), UiTokens.RULER_INK)
	draw_rect(Rect2(x_start - 6, top - px, WIDTH - x_start + 6, px), UiTokens.RULER_INK)

	var m := 0
	while origin_x + m * ppm <= WIDTH:
		var x := origin_x + m * ppm
		var big := m % 5 == 0
		var h := TAPE_H * (0.55 if big else 0.3)
		draw_rect(Rect2(x - px * 0.5, top, px, h), UiTokens.RULER_INK)
		if not big:
			# Meio metro: risquinho menor, como numa trena de verdade.
			draw_rect(Rect2(x + ppm * 0.5 - px * 0.5, top, px, TAPE_H * 0.18), UiTokens.RULER_INK)
		if big:
			var label := str(m) if m > 0 else "0 m"
			draw_string(
				_font,
				Vector2(x + 3, top + TAPE_H - 2),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				UiTokens.FONT_XS,
				UiTokens.RULER_INK
			)
		m += 1


## Faixa tracejada no chao por onde o tanque pode andar (A e D).
func _draw_move_zone() -> void:
	var px := float(UiTokens.PX)
	draw_rect(Rect2(move_zone.x, ground_y - 6, move_zone.y - move_zone.x, 6), UiTokens.MOVE_ZONE)
	var x := move_zone.x
	while x < move_zone.y:
		draw_rect(Rect2(x, ground_y - px, minf(px * 4, move_zone.y - x), px), UiTokens.EDITABLE)
		x += px * 8
	for edge in [move_zone.x, move_zone.y]:
		draw_rect(Rect2(edge - px, ground_y - 14, px * 2, 14), UiTokens.EDITABLE)
