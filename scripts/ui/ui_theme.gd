class_name UiTheme
extends RefCounted
## Constroi o Theme do jogo a partir de UiTokens.
##
## O tema NAO e aplicado em runtime: ele e compilado para
## assets/resources/ui_theme.tres e registrado em project.godot como
## gui/theme/custom. A razao e concreta -- CanvasLayer nao e Control nem Window,
## entao ele INTERROMPE a heranca de tema. Medido: um Button filho direto de um
## Control do root recebe o tema; o mesmo Button dentro de um CanvasLayer recebe
## o default do Godot. Como menu, HUD da arena e todos os modais deste projeto
## vivem em CanvasLayer, setar root.theme nao pintaria quase nada.
##
## O tema de projeto e consultado como fallback por qualquer Control sem theme
## owner, atravessando CanvasLayer sem problema.
##
## Ao mexer em UiTokens ou aqui, REGERE o .tres:
##
##     godot --headless --script res://tools/build_ui_theme.gd
##
## Aviso que vale para quem for migrar uma tela: add_theme_*_override() VENCE o
## tema. Enquanto os overrides inline continuarem no script da tela, nada daqui
## aparece. Migrar uma tela e remover override, nao acrescentar.
##
## A fonte fica sendo a embutida do Godot, de proposito. Antes o war_map e a
## arena usavam SystemFont "Georgia", que depende da maquina do jogador e no
## build Linux cai para DejaVu com metricas ~10% maiores, estourando larguras
## calculadas no Windows.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = UiTokens.FONT_MD

	_build_button(theme)
	_build_surfaces(theme)
	_build_label(theme)
	_build_slider(theme)
	_build_progress(theme)
	_build_separator(theme)

	return theme


static func _build_button(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", UiButton.make_style(UiTokens.BG_BUTTON, UiTokens.BORDER))
	theme.set_stylebox(
		"hover", "Button", UiButton.make_style(UiTokens.BG_BUTTON_HOVER, UiTokens.BORDER_HOVER)
	)
	# Sem sombra no pressed: e o que da a sensacao de afundar.
	theme.set_stylebox(
		"pressed",
		"Button",
		UiButton.make_style(UiTokens.BG_BUTTON_PRESSED, UiTokens.BORDER_PRESSED, false)
	)
	theme.set_stylebox(
		"disabled",
		"Button",
		UiButton.make_style(UiTokens.BG_BUTTON_DISABLED, UiTokens.BORDER_DISABLED, false)
	)
	# Focus existe para teclado e controle. Os botoes de HUD usam FOCUS_NONE,
	# entao na pratica so aparece se alguem navegar por Tab.
	theme.set_stylebox(
		"focus", "Button", UiButton.make_style(UiTokens.BG_BUTTON_HOVER, UiTokens.AMBER)
	)

	theme.set_color("font_color", "Button", UiTokens.TEXT)
	theme.set_color("font_hover_color", "Button", UiTokens.TEXT_HOVER)
	theme.set_color("font_pressed_color", "Button", UiTokens.TEXT_DIM)
	theme.set_color("font_disabled_color", "Button", UiTokens.TEXT_DISABLED)
	theme.set_color("font_focus_color", "Button", UiTokens.TEXT_HOVER)
	theme.set_font_size("font_size", "Button", UiTokens.FONT_MD)

	# Os icones vem do pack Kenney com as cores originais -- o joystick e preto,
	# e sobre o fundo escuro do tema ele sumia. Modular alinha todos a cor do
	# texto e faz o icone acompanhar o estado do botao.
	theme.set_color("icon_normal_color", "Button", UiTokens.TEXT)
	theme.set_color("icon_hover_color", "Button", UiTokens.TEXT_HOVER)
	theme.set_color("icon_pressed_color", "Button", UiTokens.TEXT_DIM)
	theme.set_color("icon_disabled_color", "Button", UiTokens.TEXT_DISABLED)
	# Com expand_icon ligado, sem teto o icone cresce ate a altura do botao e
	# fica maior que o proprio rotulo.
	theme.set_constant("icon_max_width", "Button", UiTokens.FONT_LG)
	# Sem isto o icone encosta no rotulo.
	theme.set_constant("h_separation", "Button", UiTokens.BTN_ICON_GAP)


static func _build_surfaces(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", UiPanel.create(UiPanel.Kind.PANEL))
	theme.set_stylebox("panel", "PanelContainer", UiPanel.create(UiPanel.Kind.PANEL))


static func _build_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", UiTokens.TEXT)
	theme.set_font_size("font_size", "Label", UiTokens.FONT_MD)


static func _build_slider(theme: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = UiTokens.ARMOR_BG
	UiPanel.set_radius(track, 4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)

	var filled := StyleBoxFlat.new()
	filled.bg_color = UiTokens.AMBER
	UiPanel.set_radius(filled, 4)
	filled.content_margin_top = 4
	filled.content_margin_bottom = 4
	theme.set_stylebox("grabber_area", "HSlider", filled)

	var filled_hi: StyleBoxFlat = filled.duplicate()
	filled_hi.bg_color = UiTokens.TEXT_HOVER
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled_hi)


static func _build_progress(theme: Theme) -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = UiTokens.ARMOR_BG
	UiPanel.set_radius(back, 4)
	theme.set_stylebox("background", "ProgressBar", back)

	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTokens.ARMOR_FILL
	UiPanel.set_radius(fill, 4)
	theme.set_stylebox("fill", "ProgressBar", fill)

	theme.set_color("font_color", "ProgressBar", UiTokens.TEXT)
	theme.set_font_size("font_size", "ProgressBar", UiTokens.FONT_XS)


static func _build_separator(theme: Theme) -> void:
	var line := StyleBoxFlat.new()
	line.bg_color = UiTokens.BORDER
	line.content_margin_top = 1
	line.content_margin_bottom = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_stylebox("separator", "VSeparator", line)
