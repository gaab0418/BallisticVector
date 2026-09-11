class_name ArenaHud
extends CanvasLayer
## Toda a interface sobreposta ao combate, extraida do _setup_ui() da arena.
##
## A extracao serviu a duas coisas. Primeiro o teto de 1000 linhas do .gdlintrc:
## arena.gd estava em 923 e nao cabia mais nada. Segundo a escala -- a HUD era
## desenhada em pixels 1:1 do canvas de 1280x720 enquanto o mundo encolhia por
## script (o tanque e um sprite de 676 px em scale 0.25, ou seja 169 px), e o
## painel de variaveis media 688 px: quatro vezes o personagem. Os corpos de
## fonte cairam para a escala de UiTokens e as celulas para o que o conteudo
## realmente exige.
##
## O posicionamento tambem mudou de coordenada absoluta para ancora. Antes so o
## botao de ajuda era ancorado; mudar a resolucao de projeto deslocaria todo o
## resto.

signal pause_pressed
signal help_pressed
signal next_stage_pressed

const AmmoIconScript = preload("res://scripts/ammo_icon.gd")
const ParabolaHudScript = preload("res://scripts/parabola_hud.gd")

const ICON_GEAR = preload("res://assets/sprites/icons/gear_white.png")
const ICON_FLAG = preload("res://assets/sprites/cartography/Default/flag.png")

const PAUSE_BTN_SIZE := Vector2(40, 40)
const HELP_BTN_SIZE := Vector2(44, 44)
const NEXT_BTN_SIZE := Vector2(190, 38)
const AMMO_ICON_SIZE := Vector2(30, 30)
const ARMOR_BAR_SIZE := Vector2(120, 14)
const STAGE_BADGE_SIZE := Vector2(230, 56)
const STAGE_FLAG_SIZE := Vector2(22, 22)
const MARGIN := 16.0

var parabola: Control

var _ammo_label: Label
var _ammo_icon: Control
var _ammo_name_label: Label
var _armor_bar: ProgressBar
var _stage_name_label: Label
var _stage_phase_label: Label
var _next_stage_btn: Button


func _ready() -> void:
	name = "HUD"
	_build_stacked_panels()
	_build_corner_controls()


## Painel de variaveis no topo e painel de recursos embaixo, ambos centrados.
## O VBox ocupando a tela inteira e o que centraliza de verdade: um preset
## calcularia offsets contra o size do instante e nao acompanharia a viewport.
func _build_stacked_panels() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = MARGIN * 0.5
	column.offset_bottom = -MARGIN

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_row)

	parabola = ParabolaHudScript.new()
	top_row.add_child(parabola)
	parabola.setup(UiPanel.create(UiPanel.Kind.HUD))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom_row)
	bottom_row.add_child(_build_resource_panel())


func _build_resource_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.HUD))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP_LG)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var ammo_column := VBoxContainer.new()
	ammo_column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(ammo_column)

	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_column.add_child(ammo_row)

	_ammo_icon = AmmoIconScript.new()
	_ammo_icon.custom_minimum_size = AMMO_ICON_SIZE
	ammo_row.add_child(_ammo_icon)

	_ammo_label = Label.new()
	_ammo_label.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	_ammo_label.add_theme_color_override("font_color", UiTokens.AMBER)
	ammo_row.add_child(_ammo_label)

	_ammo_name_label = Label.new()
	_ammo_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ammo_name_label.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	_ammo_name_label.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	ammo_column.add_child(_ammo_name_label)

	row.add_child(VSeparator.new())

	var armor_column := VBoxContainer.new()
	armor_column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(armor_column)

	var armor_title := Label.new()
	armor_title.text = "Blindagem"
	armor_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	armor_title.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	armor_title.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	armor_column.add_child(armor_title)

	# Sem stylebox inline: fundo e preenchimento vem do Theme global.
	_armor_bar = ProgressBar.new()
	_armor_bar.custom_minimum_size = ARMOR_BAR_SIZE
	_armor_bar.show_percentage = false
	armor_column.add_child(_armor_bar)

	return panel


## Badge "Base Alpha / Fase 2 de 3": mesma linguagem visual do painel de recursos
## (icone + coluna de texto sobre stylebox HUD) em vez de um Label solto sem fundo.
func _build_stage_badge() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.HUD))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.PAD_SM)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var flag_icon := TextureRect.new()
	flag_icon.texture = ICON_FLAG
	flag_icon.custom_minimum_size = STAGE_FLAG_SIZE
	flag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag_icon.modulate = UiTokens.AMBER
	flag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(flag_icon)

	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 0)
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)

	_stage_name_label = Label.new()
	_stage_name_label.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	_stage_name_label.add_theme_color_override("font_color", UiTokens.AMBER)
	text_column.add_child(_stage_name_label)

	_stage_phase_label = Label.new()
	_stage_phase_label.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	_stage_phase_label.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	text_column.add_child(_stage_phase_label)

	return panel


func _build_corner_controls() -> void:
	var pause_btn := UiButton.create("", UiButton.Kind.ICON, ICON_GEAR)
	pause_btn.custom_minimum_size = PAUSE_BTN_SIZE
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	add_child(pause_btn)
	pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pause_btn.offset_left = MARGIN
	pause_btn.offset_top = MARGIN
	pause_btn.offset_right = MARGIN + PAUSE_BTN_SIZE.x
	pause_btn.offset_bottom = MARGIN + PAUSE_BTN_SIZE.y

	var stage_badge := _build_stage_badge()
	add_child(stage_badge)
	stage_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	stage_badge.offset_left = MARGIN
	stage_badge.offset_top = MARGIN + PAUSE_BTN_SIZE.y + 8.0
	stage_badge.offset_right = stage_badge.offset_left + STAGE_BADGE_SIZE.x
	stage_badge.offset_bottom = stage_badge.offset_top + STAGE_BADGE_SIZE.y

	var help_btn := UiButton.create("?", UiButton.Kind.ICON)
	help_btn.custom_minimum_size = HELP_BTN_SIZE
	help_btn.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	help_btn.pressed.connect(func(): help_pressed.emit())
	add_child(help_btn)
	help_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	help_btn.offset_left = -MARGIN - HELP_BTN_SIZE.x
	help_btn.offset_top = MARGIN
	help_btn.offset_right = -MARGIN
	help_btn.offset_bottom = MARGIN + HELP_BTN_SIZE.y

	_next_stage_btn = UiButton.create("Próxima Fase", UiButton.Kind.PRIMARY)
	_next_stage_btn.custom_minimum_size = NEXT_BTN_SIZE
	_next_stage_btn.visible = false
	_next_stage_btn.pressed.connect(func(): next_stage_pressed.emit())
	add_child(_next_stage_btn)
	_next_stage_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_next_stage_btn.offset_left = -MARGIN - NEXT_BTN_SIZE.x
	_next_stage_btn.offset_top = -NEXT_BTN_SIZE.y * 0.5
	_next_stage_btn.offset_right = -MARGIN
	_next_stage_btn.offset_bottom = NEXT_BTN_SIZE.y * 0.5


# ═════════════════════════════════════════════════════════════════════
#  API — a arena empurra estado, a HUD nao consulta ninguem
# ═════════════════════════════════════════════════════════════════════


func set_ammo(count: int, color: Color, ammo_name: String) -> void:
	if _ammo_label:
		_ammo_label.text = "x" + str(count)
	if _ammo_icon:
		_ammo_icon.ammo_color = color
		_ammo_icon.queue_redraw()
	if _ammo_name_label:
		_ammo_name_label.text = ammo_name


## max_value vem do Global em vez de 100 literal: se a blindagem maxima mudar --
## um upgrade de loja, por exemplo -- a barra acompanha em vez de mentir.
func set_armor(value: float, max_value: float) -> void:
	if _armor_bar == null:
		return
	_armor_bar.max_value = max_value
	_armor_bar.value = value


func set_stage(base_name: String, stage_number: int, total_stages: int) -> void:
	if _stage_name_label:
		_stage_name_label.text = base_name
	if _stage_phase_label:
		_stage_phase_label.text = "Fase %d de %d" % [stage_number, total_stages]


func show_next_stage(text: String) -> void:
	if _next_stage_btn:
		_next_stage_btn.text = text
		_next_stage_btn.visible = true


func hide_next_stage() -> void:
	if _next_stage_btn:
		_next_stage_btn.visible = false
