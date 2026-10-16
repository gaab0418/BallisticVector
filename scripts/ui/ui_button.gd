class_name UiButton
extends RefCounted
## Fabrica unica de botoes do jogo.
##
## make_style() e a fonte de verdade do desenho do botao: o Theme global chama
## para pintar o padrao e as variantes chamam para se derivar dele. Construir a
## partir dos tokens, e nao de get_theme_stylebox(), e proposital -- um Control
## fora da arvore ainda nao enxerga o tema herdado e devolveria o default do
## Godot.
##
## Os quatro estados tem leitura propria, sem depender so de cor:
##   normal   -- moldura em relevo com sombra dura embaixo
##   hover    -- miolo e latao mais claros
##   pressed  -- bisel invertido, sem sombra e conteudo um pixel abaixo: afunda
##   focus    -- anel ambar por fora, para quem navega por teclado

const SFX_HOVER := "res://assets/audio/menu_hover_.ogg"
const SFX_CLICK := "res://assets/audio/menu_click.ogg"

enum Kind {
	SECONDARY,  # o padrao das telas; identico ao Theme global
	PRIMARY,  # acao em destaque (Atacar, Comprar, Continuar)
	DANGER,  # acao destrutiva dentro de uma confirmacao
	ICON,  # quadrado, so icone
}


## O desenho do botao em um estado.
##
## pad_h existe porque o botao so-icone precisa de menos: com 16 de cada lado,
## um icone de 26 px dentro de um botao de 48 nao teria onde caber.
static func make_style(
	bg: Color, border: Color, pressed: bool = false, pad_h: int = UiTokens.BTN_PAD_H
) -> UiFrame:
	var box := UiPanel.frame(bg, border, 1, 0)
	box.inset = pressed
	box.shadow_units = 0 if pressed else 2
	# A moldura ocupa 2 unidades; o respiro vem por cima disso.
	var edge := UiTokens.PX * 2
	box.content_margin_left = edge + pad_h
	box.content_margin_right = edge + pad_h
	box.content_margin_top = edge + UiTokens.BTN_PAD_V + (UiTokens.PX if pressed else 0)
	box.content_margin_bottom = edge + UiTokens.BTN_PAD_V - (UiTokens.PX if pressed else 0)
	return box


## Anel de foco desenhado por cima do estado atual.
static func make_focus_style() -> UiFrame:
	var ring := UiFrame.new()
	ring.unit = UiTokens.PX
	ring.ring_only = true
	ring.border = UiTokens.EDITABLE
	return ring


## `focusable` liga a navegacao por teclado. Fica desligada por padrao porque,
## num jogo que le as setas como gameplay, um botao com foco sequestra
## ui_left/right/up/down e faz o Espaco aciona-lo alem de disparar o canhao.
## Telas sem gameplay por baixo (menu, modais do mapa) podem ligar.
static func create(
	text: String, kind: int = Kind.SECONDARY, icon: Texture2D = null, focusable: bool = false
) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE

	if icon != null:
		btn.icon = icon
		btn.expand_icon = true

	match kind:
		Kind.PRIMARY:
			btn.custom_minimum_size = UiTokens.BTN_MIN
			_apply_accent(
				btn,
				UiTokens.EDITABLE,
				UiTokens.BG_PRIMARY,
				UiTokens.BG_PRIMARY_HOVER,
				UiTokens.BRASS
			)
		Kind.DANGER:
			btn.custom_minimum_size = UiTokens.BTN_MIN
			_apply_accent(
				btn,
				UiTokens.TEXT_HOVER,
				UiTokens.BG_DANGER,
				UiTokens.BG_DANGER_HOVER,
				UiTokens.DANGER
			)
		Kind.ICON:
			btn.custom_minimum_size = UiTokens.BTN_ICON
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			# Aqui o icone e o conteudo, nao um adorno ao lado do texto.
			btn.add_theme_constant_override("icon_max_width", UiTokens.BTN_ICON_ONLY_MAX)
			_apply_tight_padding(btn)
		_:
			btn.custom_minimum_size = UiTokens.BTN_MIN

	_wire_audio(btn)
	return btn


## Variante colorida: mesmo desenho do padrao com outro miolo, outra borda e
## outra cor de texto. O hover continua clareando para o feedback nao sumir.
static func _apply_accent(
	btn: Button, text_color: Color, bg: Color, bg_hover: Color, border: Color
) -> void:
	btn.add_theme_stylebox_override("normal", make_style(bg, border))
	btn.add_theme_stylebox_override("hover", make_style(bg_hover, UiTokens.BRASS_LIGHT))
	btn.add_theme_stylebox_override("pressed", make_style(bg, border, true))
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", UiTokens.TEXT_HOVER)
	btn.add_theme_color_override("font_focus_color", text_color)


## O botao quadrado nao tem rotulo ao lado do icone, entao o respiro horizontal
## dos botoes de texto so serviria para espremer o icone.
static func _apply_tight_padding(btn: Button) -> void:
	var pad := UiTokens.BTN_PAD_V
	btn.add_theme_stylebox_override(
		"normal", make_style(UiTokens.BG_BUTTON, UiTokens.BORDER, false, pad)
	)
	btn.add_theme_stylebox_override(
		"hover", make_style(UiTokens.BG_BUTTON_HOVER, UiTokens.BORDER_HOVER, false, pad)
	)
	btn.add_theme_stylebox_override(
		"pressed", make_style(UiTokens.BG_BUTTON_PRESSED, UiTokens.BORDER_PRESSED, true, pad)
	)


## Som de hover, foco e clique em todo botao criado aqui.
static func _wire_audio(btn: Button) -> void:
	btn.mouse_entered.connect(func(): _play(btn, SFX_HOVER))
	btn.focus_entered.connect(func(): _play(btn, SFX_HOVER))
	btn.pressed.connect(func(): _play(btn, SFX_CLICK))


## O autoload e resolvido por caminho, e nao pelo identificador global, porque
## o compilador de theme (tools/build_ui_theme.gd) roda sem autoloads e
## referenciar AudioManager direto faria este arquivo nao compilar la.
static func _play(node: Node, path: String) -> void:
	if not node.is_inside_tree():
		return
	var audio := node.get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx(path)
