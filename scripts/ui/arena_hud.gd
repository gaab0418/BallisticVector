class_name ArenaHud
extends CanvasLayer
## Toda a interface sobreposta ao combate.
##
## Layout, pensado para nao tapar a parabola:
##   topo esquerdo  -- pausa e insignia da fase (base, capitulo, numero)
##   topo centro    -- painel da equacao e engrenagens; gaveta "ver conta" embaixo
##   topo direito   -- ajuda e botao de estrela (missao e desafios, recolhidos)
##   base           -- municao e blindagem, deitadas no chao abaixo da regua
## O meio da tela fica livre para a curva, o vertice e os avioes.
## Posicionada so por ancora e container, para acompanhar a resolucao.

signal pause_pressed
signal help_pressed
## Botao de estrela: reabre o cartao de missao com o progresso dos desafios.
signal goals_pressed

const AmmoIconScript = preload("res://scripts/ammo_icon.gd")
const ParabolaHudScript = preload("res://scripts/parabola_hud.gd")

const ICON_GEAR = preload("res://assets/sprites/icons/gear_white.png")

const AMMO_ICON_SIZE := Vector2(28, 28)
const ARMOR_BAR_SIZE := Vector2(150, 22)
const MARGIN := 14.0

var parabola: Control
var formula: FormulaDrawer

var _ammo_label: Label
var _ammo_icon: Control
var _ammo_name_label: Label
var _armor: UiStatBar
var _move_hint: Label
var _stage_name_label: Label
var _stage_phase_label: Label
var _goals_btn: Button
var _goals_count: Label
var _toast: Label
var _badge: Control
var _strip: Control
var _right_row: Control
var _left_col: Control
var _toast_tween: Tween


func _ready() -> void:
	name = "HUD"
	_build_center()
	_build_left()
	_build_right()
	_build_bottom()
	_build_toast()


## Retangulo do painel central em coordenadas de tela, para a trajetoria saber
## quando o vertice esta escondido atras dele.
func top_panel_rect() -> Rect2:
	if parabola == null:
		return Rect2()
	return parabola.get_global_rect()


## Todos os paineis da HUD em coordenadas de tela: a trajetoria nao poe rotulo
## em cima deles e troca o vertice escondido por uma seta.
func occluder_rects() -> Array:
	var out := []
	for c in [parabola, formula, _badge, _strip, _right_row, _left_col]:
		if c != null and c.visible:
			out.append(c.get_global_rect())
	return out


func _build_center() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.offset_top = 6.0

	parabola = ParabolaHudScript.new()
	parabola.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(parabola)
	parabola.setup(UiPanel.create(UiPanel.Kind.HUD))

	formula = FormulaDrawer.new()
	formula.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(formula)
	parabola.formula_toggled.connect(formula.toggle)


func _build_left() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	column.offset_left = MARGIN
	column.offset_top = MARGIN

	var pause_btn := UiButton.create("", UiButton.Kind.ICON, ICON_GEAR)
	pause_btn.tooltip_text = "Pausa (Esc)"
	pause_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	column.add_child(pause_btn)

	_left_col = pause_btn
	var badge := PanelContainer.new()
	_badge = badge
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.HUD))
	column.add_child(badge)

	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 0)
	badge.add_child(text_column)

	_stage_name_label = Label.new()
	_stage_name_label.theme_type_variation = &"TitleLabel"
	_stage_name_label.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	text_column.add_child(_stage_name_label)

	_stage_phase_label = Label.new()
	_stage_phase_label.theme_type_variation = &"CaptionLabel"
	_stage_phase_label.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	text_column.add_child(_stage_phase_label)


func _build_right() -> void:
	var row := HBoxContainer.new()
	_right_row = row
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -MARGIN
	row.offset_top = MARGIN

	# Missao recolhida: estrela e placar; o cartao completo abre ao clicar.
	_goals_btn = UiButton.create("", UiButton.Kind.ICON)
	_goals_btn.tooltip_text = "Missão e desafios da fase"
	_goals_btn.custom_minimum_size = Vector2(88, 48)
	_goals_btn.pressed.connect(func(): goals_pressed.emit())
	row.add_child(_goals_btn)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	_goals_btn.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_child(UiIcon.make("star", UiTokens.EDITABLE, 26.0))
	_goals_count = Label.new()
	_goals_count.add_theme_font_override("font", UiTheme.body_font(UiTokens.WEIGHT_BOLD))
	_goals_count.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	inner.add_child(_goals_count)

	var help_btn := UiButton.create("?", UiButton.Kind.ICON)
	help_btn.tooltip_text = "Ajuda (H)"
	help_btn.add_theme_font_size_override("font_size", UiTokens.FONT_XL)
	help_btn.pressed.connect(func(): help_pressed.emit())
	row.add_child(help_btn)


func _build_bottom() -> void:
	var strip := PanelContainer.new()
	_strip = strip
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Moldura fina: a faixa mora no chao, entre a regua e a borda da tela.
	strip.add_theme_stylebox_override(
		"panel", UiPanel.frame(UiTokens.BG_HUD, UiTokens.BORDER, 1, 2)
	)
	add_child(strip)
	strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip.offset_bottom = -3.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP)
	strip.add_child(row)

	_ammo_icon = AmmoIconScript.new()
	_ammo_icon.custom_minimum_size = AMMO_ICON_SIZE
	row.add_child(_ammo_icon)

	_ammo_label = Label.new()
	_ammo_label.add_theme_font_override("font", UiTheme.body_font(UiTokens.WEIGHT_BOLD))
	_ammo_label.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	row.add_child(_ammo_label)

	_ammo_name_label = Label.new()
	_ammo_name_label.theme_type_variation = &"CaptionLabel"
	_ammo_name_label.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	row.add_child(_ammo_name_label)

	row.add_child(VSeparator.new())

	_armor = UiStatBar.new()
	_armor.setup("shield", ARMOR_BAR_SIZE)
	_armor.tooltip_text = "Blindagem do tanque"
	row.add_child(_armor)

	_move_hint = Label.new()
	_move_hint.theme_type_variation = &"CaptionLabel"
	_move_hint.add_theme_color_override("font_color", UiTokens.EDITABLE)
	_move_hint.text = "A ← → D  andar"
	_move_hint.visible = false
	row.add_child(_move_hint)


## Aviso curto no meio da tela, abaixo do painel: "Desafio cumprido!" etc.
func _build_toast() -> void:
	_toast = Label.new()
	_toast.theme_type_variation = &"OverlayLabel"
	_toast.add_theme_font_size_override("font_size", UiTokens.FONT_XL)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = -120.0


# ═════════════════════════════════════════════════════════════════════
#  API -- a arena empurra estado, a HUD nao consulta ninguem
# ═════════════════════════════════════════════════════════════════════


func set_ammo(count: int, color: Color, ammo_name: String) -> void:
	if _ammo_label:
		# count < 0 = infinita (Laboratório).
		_ammo_label.text = "livre" if count < 0 else "×" + str(count)
		_ammo_label.add_theme_color_override(
			"font_color", UiTokens.DANGER if count == 0 else UiTokens.TEXT
		)
	if _ammo_icon:
		_ammo_icon.ammo_color = color
		_ammo_icon.queue_redraw()
	if _ammo_name_label:
		_ammo_name_label.text = ammo_name + "  ·  Tab troca"


## max_value vem do Global, para acompanhar mudancas na blindagem maxima.
func set_armor(value: float, max_value: float) -> void:
	if _armor:
		_armor.set_value(value, max_value)


func set_move_hint(on: bool) -> void:
	if _move_hint:
		_move_hint.visible = on


## Laboratório: selo próprio e sem botão de missão.
func set_lab(world_name: String) -> void:
	_stage_name_label.text = "Laboratório"
	_stage_phase_label.text = "Mundo: %s\nTiros grátis" % world_name
	_goals_btn.visible = false


func set_stage(base_name: String, chapter: String, number: int, total: int, title: String) -> void:
	if _stage_name_label:
		_stage_name_label.text = base_name
	if _stage_phase_label:
		_stage_phase_label.text = "Fase %d de %d\n%s" % [number, total, title]
	_stage_phase_label.tooltip_text = chapter


## Placar da estrela: estrelas garantidas ate agora.
func set_goals(_goals: Array, states: Array, _progress: Array) -> void:
	if _goals_count == null:
		return
	var done := 0
	for st in states:
		if st == StageGoals.State.DONE:
			done += 1
	# Sobre 3, como a fase: a estrela de vencer so entra quando o castelo cai.
	_goals_count.text = "%d/%d" % [done, states.size() + 1]


## Pulo da estrela quando um desafio muda: chama o olho para o botao.
func pulse_goals() -> void:
	if _goals_btn == null:
		return
	_goals_btn.pivot_offset = _goals_btn.size * 0.5
	var tw := create_tween()
	tw.tween_property(_goals_btn, "scale", Vector2(1.25, 1.25), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_goals_btn, "scale", Vector2.ONE, 0.2)


func show_toast(text: String, col: Color = UiTokens.EDITABLE) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.add_theme_color_override("font_color", col)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast.scale = Vector2(0.6, 0.6)
	_toast.pivot_offset = _toast.size * 0.5
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
