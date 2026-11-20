@tool
class_name UiKeycap
extends Control
## Tecla desenhada em codigo ("F", "Tab"), para mostrar o atalho ao lado de um
## icone na HUD.
##
## Nao usa a moldura de UiButton.make_style: com ela a tecla teria no minimo 46
## px de altura, e a HUD precisa de UiTokens.KEYCAP_H. As cores repetem a tecla
## desenhada da ajuda (face TEXT, beirada TEXT_DIM, letra INK).
##
## Nasce com MOUSE_FILTER_IGNORE: quem clica e o botao que a contem.

@export var text := "":
	set(value):
		text = value
		update_minimum_size()
		queue_redraw()


static func make(label: String) -> UiKeycap:
	var node := UiKeycap.new()
	node.text = label
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _get_minimum_size() -> Vector2:
	var label_w := _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.FONT_XS).x
	var width := maxf(UiTokens.KEYCAP_H, label_w + 2.0 * UiTokens.KEYCAP_PAD + 2.0 * UiTokens.PX)
	return Vector2(ceilf(width), UiTokens.KEYCAP_H)


func _draw() -> void:
	var px := float(UiTokens.PX)
	# Contorno de um "pixel", como os icones.
	var outer := Rect2(Vector2.ZERO, size)
	draw_rect(outer, UiTokens.NIGHT_950)
	# A beirada da tecla, que aparece embaixo da face.
	draw_rect(outer.grow(-px), UiTokens.TEXT_DIM)
	# A face tem altura: a beirada sobra mais embaixo do que em cima.
	var face := Rect2(Vector2(px * 2.0, px * 2.0), size - Vector2(px * 4.0, px * 5.0))
	draw_rect(face, UiTokens.TEXT)

	var font := _font()
	var ascent := font.get_ascent(UiTokens.FONT_XS)
	var descent := font.get_descent(UiTokens.FONT_XS)
	var baseline := face.get_center().y + (ascent - descent) * 0.5
	draw_string(
		font,
		Vector2(face.position.x, baseline),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		face.size.x,
		UiTokens.FONT_XS,
		UiTokens.INK
	)


func _font() -> Font:
	return UiTheme.body_font(UiTokens.WEIGHT_BOLD)
