class_name UiButton
extends RefCounted
## Fabrica unica de botoes do jogo.
##
## Substitui cinco implementacoes concorrentes que existiam antes:
## _create_tactical_button (menu_play), _create_texture_button (war_map),
## _create_icon_button e _create_menu_button (arena) e o botao do help_overlay.
##
## make_style() e a fonte de verdade do desenho do botao: o Theme global chama
## para pintar o padrao e as variantes chamam para se derivar dele. Construir a
## partir dos tokens, e nao de get_theme_stylebox(), e proposital -- um Control
## fora da arvore ainda nao enxerga o tema herdado e devolveria o default do
## Godot.

const SFX_HOVER := "res://assets/audio/menu_hover_.ogg"
const SFX_CLICK := "res://assets/audio/menu_click.ogg"

enum Kind {
	SECONDARY,  # o padrao das telas; identico ao Theme global
	PRIMARY,  # acao em destaque (Atacar, Comprar, Continuar)
	DANGER,  # acao destrutiva dentro de uma confirmacao
	ICON,  # quadrado, so icone
}


## O desenho do botao em um estado. Sombra so no repouso: mante-la no pressed
## faria o botao parecer flutuar justamente quando deveria afundar.
##
## pad_h existe porque o botao so-icone precisa de menos: com 14 de cada lado,
## um icone de 22 px dentro de um botao de 44 nao teria onde caber.
static func make_style(
	bg: Color, border: Color, shadow: bool = true, pad_h: int = UiTokens.BTN_PAD_H
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	UiPanel.set_border(box, UiTokens.BORDER_W, border)
	UiPanel.set_radius(box, UiTokens.RADIUS)
	box.content_margin_left = pad_h
	box.content_margin_right = pad_h
	box.content_margin_top = UiTokens.BTN_PAD_V
	box.content_margin_bottom = UiTokens.BTN_PAD_V
	if shadow:
		box.shadow_color = UiTokens.SHADOW
		box.shadow_size = UiTokens.SHADOW_SIZE
	return box


static func create(text: String, kind: int = Kind.SECONDARY, icon: Texture2D = null) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Num jogo que le as setas como gameplay, um botao com foco sequestra
	# ui_left/right/up/down para navegacao e faz o Espaco aciona-lo alem de
	# disparar o canhao. Vale para todo botao que permanece na tela.
	btn.focus_mode = Control.FOCUS_NONE

	if icon != null:
		btn.icon = icon
		btn.expand_icon = true

	match kind:
		Kind.PRIMARY:
			btn.custom_minimum_size = UiTokens.BTN_MIN
			_apply_accent(btn, UiTokens.AMBER, UiTokens.BORDER_HOVER)
		Kind.DANGER:
			btn.custom_minimum_size = UiTokens.BTN_MIN
			_apply_accent(btn, UiTokens.DANGER, UiTokens.DANGER)
		Kind.ICON:
			btn.custom_minimum_size = UiTokens.BTN_ICON
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			# Aqui o icone e o conteudo, nao um adorno ao lado do texto.
			btn.add_theme_constant_override("icon_max_width", 22)
			_apply_tight_padding(btn)
		_:
			btn.custom_minimum_size = UiTokens.BTN_MIN

	_wire_audio(btn)
	return btn


## Variante colorida: mesmo desenho do padrao, so a borda e a cor do texto
## mudam. O hover continua clareando a borda para o feedback nao sumir.
static func _apply_accent(btn: Button, text_color: Color, border: Color) -> void:
	btn.add_theme_stylebox_override("normal", make_style(UiTokens.BG_BUTTON, border))
	btn.add_theme_stylebox_override(
		"hover", make_style(UiTokens.BG_BUTTON_HOVER, UiTokens.BORDER_HOVER)
	)
	btn.add_theme_stylebox_override(
		"pressed", make_style(UiTokens.BG_BUTTON_PRESSED, border, false)
	)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", UiTokens.TEXT_HOVER)


## O botao quadrado nao tem rotulo ao lado do icone, entao o respiro horizontal
## dos botoes de texto so serviria para espremer o icone.
static func _apply_tight_padding(btn: Button) -> void:
	btn.add_theme_stylebox_override(
		"normal", make_style(UiTokens.BG_BUTTON, UiTokens.BORDER, true, UiTokens.BTN_PAD_V)
	)
	btn.add_theme_stylebox_override(
		"hover",
		make_style(UiTokens.BG_BUTTON_HOVER, UiTokens.BORDER_HOVER, true, UiTokens.BTN_PAD_V)
	)
	btn.add_theme_stylebox_override(
		"pressed",
		make_style(UiTokens.BG_BUTTON_PRESSED, UiTokens.BORDER_PRESSED, false, UiTokens.BTN_PAD_V)
	)


## O som era ligado so no menu principal; no war_map e na arena os botoes eram
## mudos no hover. Amarrar aqui garante o mesmo retorno tatil em toda tela.
static func _wire_audio(btn: Button) -> void:
	btn.mouse_entered.connect(func(): _play(btn, SFX_HOVER))
	btn.pressed.connect(func(): _play(btn, SFX_CLICK))


## O autoload e resolvido por caminho, e nao pelo identificador global, porque o
## compilador de theme (tools/build_ui_theme.gd) roda como script standalone --
## sem autoloads carregados -- e referenciar AudioManager direto faria este
## arquivo nao compilar la. De quebra, o botao passa a funcionar em qualquer
## contexto onde o autoload nao exista.
static func _play(node: Node, path: String) -> void:
	if not node.is_inside_tree():
		return
	var audio := node.get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx(path)
