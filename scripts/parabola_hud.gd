class_name ParabolaHud
extends PanelContainer
## Painel superior central da arena: a equacao da trajetoria, as tres variaveis
## que o jogador controla (cada uma com a sua engrenagem) e os dois resultados
## que a parabola desenha no mundo -- altura maxima (vertice) e alcance (raiz).
##
## Compacto de proposito (duas linhas, ~120 px): a versao anterior tinha o dobro
## da altura e escondia os avioes que voam no alto da tela.
##
## E view pura: nao le input e nao conhece o canhao. A arena empurra o estado por
## set_state() e manda girar/piscar. Todos os numeros vem de Ballistics, a mesma
## conta que desenha a curva, entao painel e mundo nunca discordam.
##
## Ligacoes visuais com o mundo:
##   valores das engrenagens em ambar   <-> arco do angulo junto ao canhao
##   resultados na cor "aim" do mundo   <-> curva, vertice e raiz desenhados
##   losango = vertice, bandeira = raiz, nos dois lugares

## Repassados das celulas, ja com o indice de qual engrenagem foi mexida.
signal gear_dragged(index: int, delta_rad: float)
signal gear_grabbed(index: int)
signal formula_toggled

const GearWidgetScript = preload("res://scripts/gear_widget.gd")

const GEAR_ANGULO: int = 0
const GEAR_FORCA: int = 1
const GEAR_GRAVIDADE: int = 2

const GEAR_WIDTH: float = 156.0
const RESULT_WIDTH: float = 104.0
const COEF_DECIMALS := [3, 2, 2]

var _gears: Array = []
var _coef_labels: Array = []
var _coef_chips: Array = []
var _coef_text := ["", "", ""]
var _chip_on: StyleBox
var _chip_off: StyleBox
var _vertex_form: Label
var _height_value: Label
var _range_value: Label
var _result_icons: Array = []
var _height_caption: Label
var _effects: Array = ["", "", ""]
var _selected := GEAR_ANGULO
var _accent: Color = UiTokens.WORLD_EARTH.aim


func setup(panel_style: StyleBox) -> void:
	panel_style.set_content_margin_all(UiTokens.PX * 2 + 4)
	add_theme_stylebox_override("panel", panel_style)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	column.add_child(_build_equation_row())

	_vertex_form = Label.new()
	_vertex_form.theme_type_variation = &"CaptionLabel"
	_vertex_form.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vertex_form.visible = false
	column.add_child(_vertex_form)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	for title in ["Ângulo", "Força", "Gravidade"]:
		var gear = GearWidgetScript.new()
		row.add_child(gear)
		gear.setup(title, GEAR_WIDTH)
		var index: int = _gears.size()
		gear.dragged.connect(_on_gear_dragged.bind(index))
		gear.grabbed.connect(_on_gear_grabbed.bind(index))
		_gears.append(gear)

	row.add_child(VSeparator.new())
	_height_value = _add_result(row, "vertex", "Altura máx.")
	_height_caption = _height_value.get_parent().get_child(0).get_child(1)
	_range_value = _add_result(row, "root", "Alcance")

	set_selected(GEAR_ANGULO)


## Cor do que e calculado neste mundo, a mesma da curva desenhada.
func set_accent(color: Color) -> void:
	_accent = color
	for icon in _result_icons:
		icon.color = color
	for label in [_height_value, _range_value]:
		label.add_theme_color_override("font_color", color)


## view: angle_deg, power, shot (Ballistics.shot), effects (3 strings),
## vertex_form (bool).
func set_state(view: Dictionary) -> void:
	if _gears.size() < 3:
		return
	var s: Dictionary = view.shot
	_gears[GEAR_ANGULO].set_value_text("%d°" % roundi(view.angle_deg))
	_gears[GEAR_FORCA].set_value_text(Ballistics.fmt(s.v) + " m/s")
	_gears[GEAR_FORCA].set_title_text("Força %d%%" % roundi(view.power * 100.0))
	_gears[GEAR_GRAVIDADE].set_value_text(Ballistics.fmt(s.g) + " m/s²")

	_effects = view.effects
	for i in range(3):
		_gears[i].set_effects(_effects[i])

	_update_equation(s)
	_update_vertex_form(s, view.get("vertex_form", false))
	_update_results(s)
	_highlight_coefs()


func set_selected(index: int) -> void:
	_selected = index
	for i in range(_gears.size()):
		_gears[i].set_selected(i == index)
	_highlight_coefs()


func spin_selected(index: int, amount: float) -> void:
	if index >= 0 and index < _gears.size():
		_gears[index].spin(amount)


func flash_selected(index: int) -> void:
	if index >= 0 and index < _gears.size():
		_gears[index].flash()


## Chamado ao trocar de municao: ambar em vez de vermelho, porque nao e erro -- e
## a gravidade da bala nova entrando em cena, e vale a crianca reparar.
func flash_gravity() -> void:
	if _gears.size() > GEAR_GRAVIDADE:
		_gears[GEAR_GRAVIDADE].flash(UiTokens.EDITABLE)


func _on_gear_dragged(delta_rad: float, index: int) -> void:
	gear_dragged.emit(index, delta_rad)


func _on_gear_grabbed(index: int) -> void:
	gear_grabbed.emit(index)


# ═════════════════════════════════════════════════════════════════════
#  EQUACAO
# ═════════════════════════════════════════════════════════════════════


func _build_equation_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)

	_chip_on = UiPanel.create(UiPanel.Kind.SELECTED)
	_chip_on.set_content_margin_all(UiTokens.PX * 2)
	var off: UiFrame = _chip_on.duplicate()
	for prop in ["fill", "outline", "border", "bevel_light", "bevel_dark"]:
		off.set(prop, UiTokens.TRANSPARENT)
	_chip_off = off

	row.add_child(_eq_label("y ="))
	for i in range(3):
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _chip_off)
		var label := _eq_label("")
		chip.add_child(label)
		row.add_child(chip)
		_coef_chips.append(chip)
		_coef_labels.append(label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(UiTokens.GAP, 0)
	row.add_child(spacer)

	var btn := UiButton.create("Ver conta (F)", UiButton.Kind.SECONDARY)
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.tooltip_text = "Mostra de onde saem a, b, c, o vértice e a raiz"
	btn.pressed.connect(func(): formula_toggled.emit())
	row.add_child(btn)
	return row


func _eq_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UiTheme.body_font(UiTokens.WEIGHT_BOLD))
	label.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	return label


## Cada coeficiente no seu chip, com o sinal separado ("+ 0,62x"). O que mudou
## desde o ultimo quadro da um pulo: e assim que a crianca ve qual numero a
## engrenagem mexeu.
func _update_equation(s: Dictionary) -> void:
	var values := [s.a, s.b, s.c]
	var suffix := ["x²", "x", ""]
	for i in range(3):
		var txt := Ballistics.term(values[i], COEF_DECIMALS[i], suffix[i], i == 0)
		if txt != _coef_text[i]:
			if _coef_text[i] != "":
				_pulse(_coef_chips[i])
			_coef_text[i] = txt
			_coef_labels[i].text = txt


func _update_vertex_form(s: Dictionary, on: bool) -> void:
	_vertex_form.visible = on
	if not on:
		return
	var v := Ballistics.vertex(s)
	_vertex_form.text = (
		"forma do vértice:  y = "
		+ Ballistics.term(s.a, 3, "", true)
		+ "(x "
		+ Ballistics.term(-v.x, 1, "")
		+ ")² "
		+ Ballistics.term(v.y, 1, "")
	)


func _highlight_coefs() -> void:
	if _coef_chips.is_empty():
		return
	var letters: String = _effects[_selected] if _selected < _effects.size() else ""
	for i in range(3):
		var on := letters.contains(["a", "b", "c"][i])
		_coef_chips[i].add_theme_stylebox_override("panel", _chip_on if on else _chip_off)
		_coef_labels[i].add_theme_color_override(
			"font_color", UiTokens.EDITABLE if on else UiTokens.TEXT
		)


func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.18, 1.18), 0.06)
	tw.tween_property(node, "scale", Vector2.ONE, 0.16)


# ═════════════════════════════════════════════════════════════════════
#  RESULTADOS
# ═════════════════════════════════════════════════════════════════════


func _add_result(row: HBoxContainer, icon_name: String, title: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(RESULT_WIDTH, 0)
	row.add_child(box)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 4)
	var icon := UiIcon.make(icon_name, _accent, 18.0)
	_result_icons.append(icon)
	head.add_child(icon)
	var caption := Label.new()
	caption.text = title.to_upper()
	caption.theme_type_variation = &"CaptionLabel"
	head.add_child(caption)
	box.add_child(head)

	var value := Label.new()
	value.theme_type_variation = &"ResultLabel"
	value.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	value.add_theme_color_override("font_color", _accent)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	return value


## Com o canhao para baixo nao ha ponto mais alto a frente. O painel diz
## "levante!" e a frase inteira aparece no mundo, junto do canhao.
func _update_results(s: Dictionary) -> void:
	var up := Ballistics.opens_up(s)
	# a > 0 (Mundo Invertido): o vertice e o ponto mais BAIXO.
	_height_caption.text = "ALTURA MÍN." if up else "ALTURA MÁX."
	if Ballistics.has_arc(s):
		_height_value.text = Ballistics.fmt(Ballistics.vertex(s).y) + " m"
	else:
		_height_value.text = "abaixe!" if up else "levante!"
	var r := Ballistics.root(s)
	_range_value.text = "não cai" if is_nan(r) else Ballistics.fmt(r) + " m"
