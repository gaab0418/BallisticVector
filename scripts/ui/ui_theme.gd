class_name UiTheme
extends RefCounted
## Constroi o Theme do jogo a partir de UiTokens.
##
## O tema e compilado para assets/resources/ui_theme.tres e registrado em
## project.godot como gui/theme/custom, em vez de aplicado em runtime:
## CanvasLayer interrompe a heranca de tema, e menu, HUD e modais vivem em
## CanvasLayer. O tema de projeto e o fallback de todo Control sem theme owner.
##
## Ao mexer em UiTokens ou aqui, REGERE o .tres:
##
##     godot --headless --script res://tools/build_ui_theme.gd
##
## add_theme_*_override() vence o tema. Para os papeis de texto use as
## variacoes prontas (Label.theme_type_variation):
##
##   TitleLabel    -- titulo de janela, Jersey 10, latao claro
##   DisplayLabel  -- logotipo e telas de resultado, Jersey 10 grande com contorno
##   HeadingLabel  -- subtitulo dentro de painel, texto em negrito
##   CaptionLabel  -- rotulo curto e discreto (nome de campo)
##   EditableLabel -- valor que o jogador muda (ambar)
##   ResultLabel   -- valor que o jogo calculou (ciano)
##   DangerLabel   -- dano e alerta
##   OverlayLabel  -- texto escrito direto sobre arte, com contorno escuro
##   InkLabel      -- texto sobre papel (PAPER)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = UiTokens.FONT_MD

	_build_button(theme)
	_build_surfaces(theme)
	_build_label(theme)
	_build_label_variations(theme)
	_build_tooltip(theme)
	_build_slider(theme)
	_build_progress(theme)
	_build_scrollbar(theme)
	_build_separator(theme)

	return theme


## Fontes do tema, aplicadas em tempo de execucao (Global._ready) no tema do
## projeto. Ficam fora do .tres porque o tema e carregado na inicializacao,
## antes de uma importacao do zero gerar os arquivos das fontes.
static func apply_fonts(theme: Theme) -> void:
	var bold := body_font(UiTokens.WEIGHT_BOLD)
	theme.default_font = body_font()
	theme.set_font("font", "Button", bold)
	theme.set_font("font", "ProgressBar", bold)
	for type_name in ["TitleLabel", "DisplayLabel"]:
		theme.set_font("font", type_name, title_font())
	for type_name in [
		"HeadingLabel", "EditableLabel", "ResultLabel", "DangerLabel", "OverlayLabel"
	]:
		theme.set_font("font", type_name, bold)


## Fonte de texto (VT323) com o Handjet de fallback para θ e setas. `weight`
## WEIGHT_BOLD liga o engrossamento sintetico.
static func body_font(weight: int = UiTokens.WEIGHT_BODY) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = load(UiTokens.FONT_BODY_PATH)
	font.fallbacks = [load(UiTokens.FONT_FALLBACK_PATH)]
	if weight == UiTokens.WEIGHT_BOLD:
		font.variation_embolden = UiTokens.EMBOLDEN
	return font


static func title_font() -> Font:
	return load(UiTokens.FONT_TITLE_PATH)


static func _build_button(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", UiButton.make_style(UiTokens.BG_BUTTON, UiTokens.BORDER))
	theme.set_stylebox(
		"hover", "Button", UiButton.make_style(UiTokens.BG_BUTTON_HOVER, UiTokens.BORDER_HOVER)
	)
	theme.set_stylebox(
		"pressed",
		"Button",
		UiButton.make_style(UiTokens.BG_BUTTON_PRESSED, UiTokens.BORDER_PRESSED, true)
	)
	theme.set_stylebox(
		"disabled",
		"Button",
		UiButton.make_style(UiTokens.BG_BUTTON_DISABLED, UiTokens.BORDER_DISABLED, true)
	)
	# Foco e um anel por fora, desenhado por cima do estado atual. Os botoes de
	# HUD usam FOCUS_NONE; menu e modais ligam o foco para navegar por teclado.
	theme.set_stylebox("focus", "Button", UiButton.make_focus_style())

	theme.set_color("font_color", "Button", UiTokens.TEXT)
	theme.set_color("font_hover_color", "Button", UiTokens.TEXT_HOVER)
	theme.set_color("font_pressed_color", "Button", UiTokens.TEXT_DIM)
	theme.set_color("font_disabled_color", "Button", UiTokens.TEXT_DISABLED)
	theme.set_color("font_focus_color", "Button", UiTokens.TEXT_HOVER)
	theme.set_color("font_hover_pressed_color", "Button", UiTokens.TEXT_DIM)
	theme.set_font_size("font_size", "Button", UiTokens.FONT_MD)

	# Icones do pack Kenney tem cores proprias (alguns pretos): modular alinha
	# todos a cor do texto e faz o icone acompanhar o estado do botao.
	theme.set_color("icon_normal_color", "Button", UiTokens.TEXT)
	theme.set_color("icon_hover_color", "Button", UiTokens.TEXT_HOVER)
	theme.set_color("icon_pressed_color", "Button", UiTokens.TEXT_DIM)
	theme.set_color("icon_disabled_color", "Button", UiTokens.TEXT_DISABLED)
	theme.set_color("icon_focus_color", "Button", UiTokens.TEXT_HOVER)
	# Com expand_icon ligado, sem teto o icone cresce ate a altura do botao e
	# fica maior que o proprio rotulo.
	theme.set_constant("icon_max_width", "Button", UiTokens.BTN_ICON_MAX)
	theme.set_constant("h_separation", "Button", UiTokens.BTN_ICON_GAP)


static func _build_surfaces(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", UiPanel.create(UiPanel.Kind.PANEL))
	theme.set_stylebox("panel", "PanelContainer", UiPanel.create(UiPanel.Kind.PANEL))


static func _build_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", UiTokens.TEXT)
	theme.set_color("font_outline_color", "Label", UiTokens.TEXT_OUTLINE)
	theme.set_color("font_shadow_color", "Label", UiTokens.SHADOW)
	theme.set_font_size("font_size", "Label", UiTokens.FONT_MD)


## Cada variacao declara so o que difere de Label. Uma tela aplica com
## label.theme_type_variation = &"ResultLabel" e nao escreve override nenhum.
static func _build_label_variations(theme: Theme) -> void:
	_variation(theme, "TitleLabel", UiTokens.FONT_TITLE, UiTokens.TITLE)

	_variation(theme, "DisplayLabel", UiTokens.FONT_DISPLAY, UiTokens.EDITABLE)
	theme.set_constant("outline_size", "DisplayLabel", UiTokens.OUTLINE_SIZE)
	theme.set_constant("shadow_offset_x", "DisplayLabel", 0)
	theme.set_constant("shadow_offset_y", "DisplayLabel", UiTokens.PX * 3)

	_variation(theme, "HeadingLabel", UiTokens.FONT_LG, UiTokens.BRASS_LIGHT)
	_variation(theme, "CaptionLabel", UiTokens.FONT_XS, UiTokens.TEXT_MUTED)
	_variation(theme, "EditableLabel", UiTokens.FONT_LG, UiTokens.EDITABLE)
	_variation(theme, "ResultLabel", UiTokens.FONT_LG, UiTokens.CALCULATED)
	_variation(theme, "DangerLabel", UiTokens.FONT_MD, UiTokens.DANGER)

	_variation(theme, "OverlayLabel", UiTokens.FONT_SM, UiTokens.TEXT)
	theme.set_constant("outline_size", "OverlayLabel", UiTokens.TEXT_OUTLINE_SIZE)

	_variation(theme, "InkLabel", UiTokens.FONT_MD, UiTokens.INK)


static func _variation(theme: Theme, type_name: String, size: int, color: Color) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_font_size("font_size", type_name, size)
	theme.set_color("font_color", type_name, color)


static func _build_tooltip(theme: Theme) -> void:
	theme.set_stylebox("panel", "TooltipPanel", UiPanel.create(UiPanel.Kind.CARD))
	theme.set_color("font_color", "TooltipLabel", UiTokens.TEXT)
	theme.set_font_size("font_size", "TooltipLabel", UiTokens.FONT_SM)


## Faixa simples em StyleBoxFlat: no tamanho de um trilho, a moldura de pixel
## art viraria so contorno.
static func _flat(color: Color, margin_v: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.anti_aliasing = false
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


static func _build_slider(theme: Theme) -> void:
	var track := _flat(UiTokens.ARMOR_BG, UiTokens.PX * 2)
	UiPanel.set_border(track, UiTokens.PX, UiTokens.BORDER)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", _flat(UiTokens.EDITABLE, UiTokens.PX * 2))
	theme.set_stylebox(
		"grabber_area_highlight", "HSlider", _flat(UiTokens.TEXT_HOVER, UiTokens.PX * 2)
	)


static func _build_progress(theme: Theme) -> void:
	var back := _flat(UiTokens.ARMOR_BG)
	UiPanel.set_border(back, UiTokens.PX, UiTokens.BORDER)
	theme.set_stylebox("background", "ProgressBar", back)

	var fill := _flat(UiTokens.ARMOR_FILL)
	UiPanel.set_border(fill, UiTokens.PX, UiTokens.TRANSPARENT)
	theme.set_stylebox("fill", "ProgressBar", fill)

	theme.set_color("font_color", "ProgressBar", UiTokens.TEXT)
	theme.set_color("font_outline_color", "ProgressBar", UiTokens.TEXT_OUTLINE)
	theme.set_constant("outline_size", "ProgressBar", UiTokens.TEXT_OUTLINE_SIZE)
	theme.set_font_size("font_size", "ProgressBar", UiTokens.FONT_XS)


static func _build_scrollbar(theme: Theme) -> void:
	var track := _flat(UiTokens.NIGHT_950)
	track.content_margin_left = UiTokens.PX * 3
	track.content_margin_right = UiTokens.PX * 3
	theme.set_stylebox("scroll", "VScrollBar", track)
	theme.set_stylebox("grabber", "VScrollBar", _flat(UiTokens.BRASS_DARK))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _flat(UiTokens.BRASS))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _flat(UiTokens.BRASS_LIGHT))


static func _build_separator(theme: Theme) -> void:
	var line := _flat(UiTokens.BORDER)
	# Margem nos quatro lados: o HSeparator usa a altura minima e o VSeparator a
	# largura minima como espessura da linha.
	line.set_content_margin_all(1)
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_stylebox("separator", "VSeparator", line)
	theme.set_constant("separation", "HSeparator", UiTokens.PX * 4)
	theme.set_constant("separation", "VSeparator", UiTokens.PX * 4)
