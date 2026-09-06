class_name ParabolaHud
extends PanelContainer
## Painel superior central da arena: as três variáveis que o jogador controla, cada uma
## com a sua engrenagem, mais dois valores derivados só de leitura.
##
## É view pura: não lê input e não conhece o canhão. A arena empurra o estado por
## set_state() e manda girar/piscar. Os derivados usam a fórmula do lançamento oblíquo,
## não a simulação da mira — a simulação para na borda da tela e nos obstáculos, então
## mediria "distância até a montanha" em vez de alcance.

const GearWidgetScript = preload("res://scripts/gear_widget.gd")

# O jogo trabalha em pixels e a HUD fala em metros. Com 50 px/m os stats atuais caem
# redondos: Enferrujada 16 m/s e 10 m/s² (~Terra), Perfurante 18 m/s e 6 m/s².
const PX_PER_METER: float = 50.0

const GEAR_ANGULO: int = 0
const GEAR_FORCA: int = 1
const GEAR_GRAVIDADE: int = 2

# Dimensionado para o valor mais largo, "10.0 m/s²" em corpo 30 (~126 px). Se a célula
# ficar estreita demais, o PanelContainer cresce sozinho e invade o rótulo da fase.
const GEAR_WIDTH: float = 140.0
const DERIVED_WIDTH: float = 100.0
const COLOR_DERIVED := Color(0.7, 0.85, 0.9)
const COLOR_DERIVED_DIM := Color(0.55, 0.45, 0.3)
const COLOR_DERIVED_TITLE := Color(0.75, 0.62, 0.42)
const COLOR_AMBER := Color(1.0, 0.85, 0.3)

var _gears: Array = []
var _range_value: Label
var _height_value: Label
var _font: Font


func setup(font: Font, panel_style: StyleBoxFlat) -> void:
	_font = font
	# O helper da arena não define margem interna; sem isto o conteúdo cola na borda.
	panel_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", panel_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	for title in ["Ângulo", "Força", "Gravidade"]:
		var gear = GearWidgetScript.new()
		row.add_child(gear)
		gear.setup(font, title, GEAR_WIDTH)
		_gears.append(gear)

	row.add_child(VSeparator.new())

	_range_value = _add_derived(row, "Alcance")
	_height_value = _add_derived(row, "Altura máx.")

	set_selected(GEAR_ANGULO)


## angle_deg é a elevação (positiva com o cano apontado para cima), v0_px e gravity_px
## estão nas unidades cruas do motor e power é a fração 0..1 usada no título da Força.
func set_state(angle_deg: float, v0_px: float, gravity_px: float, power: float) -> void:
	if _gears.size() < 3:
		return
	_gears[GEAR_ANGULO].set_value_text("%d°" % roundi(angle_deg))
	_gears[GEAR_FORCA].set_value_text("%.1f m/s" % (v0_px / PX_PER_METER))
	_gears[GEAR_FORCA].set_title_text("Força · %d%%" % roundi(power * 100.0))
	_gears[GEAR_GRAVIDADE].set_value_text("%.1f m/s²" % (gravity_px / PX_PER_METER))
	_update_derived(angle_deg, v0_px, gravity_px)


func set_selected(index: int) -> void:
	for i in range(_gears.size()):
		_gears[i].set_selected(i == index)


func spin_selected(index: int, amount: float) -> void:
	if index >= 0 and index < _gears.size():
		_gears[index].spin(amount)


func flash_selected(index: int) -> void:
	if index >= 0 and index < _gears.size():
		_gears[index].flash()


## Chamado ao trocar de munição: âmbar em vez de vermelho, porque não é erro — é a
## gravidade da bala nova entrando em cena, e vale a criança reparar.
func flash_gravity() -> void:
	if _gears.size() > GEAR_GRAVIDADE:
		_gears[GEAR_GRAVIDADE].flash(COLOR_AMBER)


func _update_derived(angle_deg: float, v0_px: float, g_px: float) -> void:
	if _range_value == null:
		return
	# Com o cano na horizontal ou apontado para baixo o tiro não descreve o arco que a
	# fórmula do lançamento oblíquo descreve — mostrar um número ali seria mentira.
	if angle_deg <= 0.0 or g_px <= 0.0:
		_set_derived_text(_range_value, "—", COLOR_DERIVED_DIM)
		_set_derived_text(_height_value, "—", COLOR_DERIVED_DIM)
		return
	var rad: float = deg_to_rad(angle_deg)
	var range_px: float = v0_px * v0_px * sin(2.0 * rad) / g_px
	var height_px: float = v0_px * v0_px * sin(rad) * sin(rad) / (2.0 * g_px)
	_set_derived_text(_range_value, "%d m" % roundi(range_px / PX_PER_METER), COLOR_DERIVED)
	_set_derived_text(_height_value, "%d m" % roundi(height_px / PX_PER_METER), COLOR_DERIVED)


func _set_derived_text(label: Label, text_value: String, color: Color) -> void:
	label.text = text_value
	label.add_theme_color_override("font_color", color)


func _add_derived(row: HBoxContainer, title_text: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(DERIVED_WIDTH, 0.0)
	row.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", COLOR_DERIVED_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var value := Label.new()
	value.text = "—"
	value.add_theme_font_override("font", _font)
	value.add_theme_font_size_override("font_size", 26)
	value.add_theme_color_override("font_color", COLOR_DERIVED)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	return value
