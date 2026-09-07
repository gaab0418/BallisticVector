class_name ParabolaHud
extends PanelContainer
## Painel superior central da arena: as três variáveis que o jogador controla, cada uma
## com a sua engrenagem, mais dois valores derivados só de leitura.
##
## É view pura: não lê input e não conhece o canhão. A arena empurra o estado por
## set_state() e manda girar/piscar. Os derivados usam a fórmula do lançamento oblíquo,
## não a simulação da mira — a simulação para na borda da tela e nos obstáculos, então
## mediria "distância até a montanha" em vez de alcance.

## Repassados das células, já com o índice de qual engrenagem foi mexida.
signal gear_dragged(index: int, delta_rad: float)
signal gear_grabbed(index: int)

const GearWidgetScript = preload("res://scripts/gear_widget.gd")

# O jogo trabalha em pixels e a HUD fala em metros. Com 50 px/m os stats atuais caem
# redondos: Enferrujada 16 m/s e 10 m/s² (~Terra), Perfurante 18 m/s e 6 m/s².
const PX_PER_METER: float = 50.0

const GEAR_ANGULO: int = 0
const GEAR_FORCA: int = 1
const GEAR_GRAVIDADE: int = 2

# Dimensionado para o mais largo entre o valor "10.0 m/s²" em corpo 20 (~84 px) e a
# linha da engrenagem (20 + 48 + 20 + separações = 96). Se a célula ficar estreita
# demais, o PanelContainer cresce sozinho e empurra o painel para fora do vão livre.
#
# Os valores caíram de 140/100 porque a HUD estava desproporcional ao jogo: o painel
# media 688 px de largura contra 169 px do tanque do jogador, que é um sprite de 676
# px reduzido a 0.25. A HUD ficou em 1:1 enquanto o mundo encolheu por script.
const GEAR_WIDTH: float = 100.0
const DERIVED_WIDTH: float = 76.0
const COLOR_DERIVED := Color(0.7, 0.85, 0.9)
const COLOR_DERIVED_DIM := Color(0.55, 0.45, 0.3)
const COLOR_DERIVED_TITLE := UiTokens.TEXT_MUTED
const COLOR_AMBER := UiTokens.AMBER

var _gears: Array = []
var _range_title: Label
var _range_value: Label
var _height_value: Label


func setup(panel_style: StyleBoxFlat) -> void:
	# O helper da arena não define margem interna; sem isto o conteúdo cola na borda.
	panel_style.set_content_margin_all(UiTokens.PAD_SM)
	add_theme_stylebox_override("panel", panel_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	for title in ["Ângulo", "Força", "Gravidade"]:
		var gear = GearWidgetScript.new()
		row.add_child(gear)
		gear.setup(title, GEAR_WIDTH)
		var index: int = _gears.size()
		gear.dragged.connect(_on_gear_dragged.bind(index))
		gear.grabbed.connect(_on_gear_grabbed.bind(index))
		_gears.append(gear)

	row.add_child(VSeparator.new())

	var range_pair: Array = _add_derived(row, "Alcance")
	_range_title = range_pair[0]
	_range_value = range_pair[1]
	_height_value = _add_derived(row, "Altura máx.")[1]

	set_selected(GEAR_ANGULO)


## angle_deg é a elevação (positiva com o cano apontado para cima), v0_px e gravity_px
## estão nas unidades cruas do motor e power é a fração 0..1 usada no título da Força.
func set_state(
	angle_deg: float, v0_px: float, gravity_px: float, power: float, spread_rad: float
) -> void:
	if _gears.size() < 3:
		return
	_gears[GEAR_ANGULO].set_value_text("%d°" % roundi(angle_deg))
	_gears[GEAR_FORCA].set_value_text("%.1f m/s" % (v0_px / PX_PER_METER))
	_gears[GEAR_FORCA].set_title_text("Força · %d%%" % roundi(power * 100.0))
	_gears[GEAR_GRAVIDADE].set_value_text("%.1f m/s²" % (gravity_px / PX_PER_METER))
	_update_derived(angle_deg, v0_px, gravity_px)
	_update_spread(angle_deg, v0_px, gravity_px, spread_rad)


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


func _on_gear_dragged(delta_rad: float, index: int) -> void:
	gear_dragged.emit(index, delta_rad)


func _on_gear_grabbed(index: int) -> void:
	gear_grabbed.emit(index)


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


## Alcance analítico para uma elevação qualquer. Fora de (0, 90) o tiro não descreve o
## arco que a fórmula descreve, e o alcance vira zero para efeito de faixa.
func _range_for(angle_deg: float, v0_px: float, g_px: float) -> float:
	if angle_deg <= 0.0 or angle_deg >= 90.0 or g_px <= 0.0:
		return 0.0
	var rad: float = deg_to_rad(angle_deg)
	return v0_px * v0_px * sin(2.0 * rad) / g_px


## Escreve a incerteza no título do Alcance. O desvio é assimétrico — a 45° qualquer
## erro de ângulo só encurta o tiro —, então mostramos o maior dos dois lados, que é o
## que o jogador precisa saber para não errar o alvo.
func _update_spread(angle_deg: float, v0_px: float, g_px: float, spread_rad: float) -> void:
	if _range_title == null:
		return
	var spread_deg: float = rad_to_deg(spread_rad)
	if spread_deg <= 0.01 or angle_deg <= 0.0:
		_range_title.text = "Alcance"
		return

	var center: float = _range_for(angle_deg, v0_px, g_px)
	var low: float = _range_for(angle_deg - spread_deg, v0_px, g_px)
	var high: float = _range_for(angle_deg + spread_deg, v0_px, g_px)
	# 45° é o máximo da função: se estiver dentro do intervalo, é lá que o alcance topa.
	var best: float = center
	if angle_deg - spread_deg < 45.0 and angle_deg + spread_deg > 45.0:
		best = _range_for(45.0, v0_px, g_px)
	var worst: float = min(low, high)
	var delta_px: float = max(abs(best - center), abs(center - worst))
	_range_title.text = "Alcance ±%d m" % roundi(delta_px / PX_PER_METER)


func _set_derived_text(label: Label, text_value: String, color: Color) -> void:
	label.text = text_value
	label.add_theme_color_override("font_color", color)


## Devolve [titulo, valor] — o título do Alcance é reescrito com a dispersão.
func _add_derived(row: HBoxContainer, title_text: String) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(DERIVED_WIDTH, 0.0)
	row.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	title.add_theme_color_override("font_color", COLOR_DERIVED_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var value := Label.new()
	value.text = "—"
	value.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	value.add_theme_color_override("font_color", COLOR_DERIVED)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	return [title, value]
