class_name GearWidget
extends PanelContainer
## Uma célula da HUD de parábola: título pequeno em cima, valor grande no meio e uma
## engrenagem pequena embaixo, ladeada pelas setas que a controlam.
##
## A engrenagem gira enquanto o jogador segura a seta e trava quando o valor bate no
## limite — a trava é o feedback de "não dá para ir mais longe".

const GEAR_TEXTURE = preload("res://assets/sprites/icons/gear_white.png")
const ARROW_LEFT = preload("res://assets/sprites/keyboard_mouse/keyboard_arrow_left.png")
const ARROW_RIGHT = preload("res://assets/sprites/keyboard_mouse/keyboard_arrow_right.png")

const GEAR_SIZE: float = 24.0
# Um quadrado girado ocupa lado * sqrt(2). Sem esta folga os cantos da engrenagem
# encostariam nas setas ao girar.
const GEAR_BOX: float = 34.0
const FLASH_TIME: float = 0.35

const COLOR_VALUE_ON := Color(1.0, 0.85, 0.3)
const COLOR_VALUE_OFF := Color(0.9, 0.8, 0.6)
const COLOR_TITLE_ON := Color(0.9, 0.8, 0.6)
const COLOR_TITLE_OFF := Color(0.75, 0.62, 0.42)
const COLOR_GEAR_ON := Color(1.0, 0.85, 0.3)
const COLOR_GEAR_OFF := Color(0.55, 0.45, 0.3)
const COLOR_ALERT := Color(1.0, 0.2, 0.2)
const COLOR_HINT := Color(1.0, 0.85, 0.3)

var _title: Label
var _value: Label
var _gear: TextureRect
var _arrow_l: TextureRect
var _arrow_r: TextureRect
var _style_on: StyleBoxFlat
var _style_off: StyleBoxFlat
var _value_color: Color = COLOR_VALUE_OFF
var _flash_tween: Tween


func setup(font: Font, title_text: String, width: float) -> void:
	custom_minimum_size = Vector2(width, 0.0)
	_build_styles()
	add_theme_stylebox_override("panel", _style_off)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	_title = Label.new()
	_title.text = title_text
	_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", COLOR_TITLE_OFF)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_value = Label.new()
	_value.text = "--"
	_value.add_theme_font_override("font", font)
	_value.add_theme_font_size_override("font_size", 30)
	_value.add_theme_color_override("font_color", COLOR_VALUE_OFF)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_value)

	box.add_child(_build_gear_row())


func set_title_text(text_value: String) -> void:
	if _title:
		_title.text = text_value


func set_value_text(text_value: String) -> void:
	if _value:
		_value.text = text_value


func set_selected(on: bool) -> void:
	if _value == null:
		return
	add_theme_stylebox_override("panel", _style_on if on else _style_off)
	_value_color = COLOR_VALUE_ON if on else COLOR_VALUE_OFF
	_value.add_theme_color_override("font_color", _value_color)
	_title.add_theme_color_override("font_color", COLOR_TITLE_ON if on else COLOR_TITLE_OFF)
	_gear.modulate = COLOR_GEAR_ON if on else COLOR_GEAR_OFF
	# As setas só aparecem na engrenagem ativa: ensinam qual tecla age ali, no lugar da ação.
	_arrow_l.visible = on
	_arrow_r.visible = on


func spin(amount: float) -> void:
	if _gear:
		_gear.rotation += amount


func flash(color: Color = COLOR_ALERT) -> void:
	if _value == null:
		return
	# Sem a guarda, segurar a tecla no limite reinicia o tween todo frame e a cor congela.
	if _flash_tween != null and _flash_tween.is_running():
		return
	_value.add_theme_color_override("font_color", color)
	_flash_tween = create_tween()
	_flash_tween.tween_property(
		_value, "theme_override_colors/font_color", _value_color, FLASH_TIME
	)


func _build_gear_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_arrow_l = _make_arrow(ARROW_LEFT)
	row.add_child(_arrow_l)

	# Wrapper solto para a engrenagem girar sem empurrar o layout do HBox.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(GEAR_BOX, GEAR_BOX)
	row.add_child(slot)

	_gear = TextureRect.new()
	_gear.texture = GEAR_TEXTURE
	_gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gear.modulate = COLOR_GEAR_OFF
	slot.add_child(_gear)
	# Depois do add_child: o slot é um Control simples, não um container, então ele não
	# mexe mais nestes valores — mas entrar na árvore pode reescrevê-los.
	_gear.size = Vector2(GEAR_SIZE, GEAR_SIZE)
	_gear.position = Vector2((GEAR_BOX - GEAR_SIZE) * 0.5, (GEAR_BOX - GEAR_SIZE) * 0.5)
	# Literal de propósito: size ainda pode ser (0, 0) antes do primeiro passo de layout,
	# e pivot_offset = size / 2 giraria a engrenagem em torno do canto.
	_gear.pivot_offset = Vector2(GEAR_SIZE * 0.5, GEAR_SIZE * 0.5)

	_arrow_r = _make_arrow(ARROW_RIGHT)
	row.add_child(_arrow_r)
	return row


func _make_arrow(tex: Texture2D) -> TextureRect:
	var arrow := TextureRect.new()
	arrow.texture = tex
	arrow.custom_minimum_size = Vector2(18, 18)
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.modulate = COLOR_HINT
	arrow.visible = false
	return arrow


func _build_styles() -> void:
	# Os dois estilos têm a MESMA border_width: sem isso a célula muda de tamanho ao ser
	# selecionada e o HBox inteiro treme a cada troca de engrenagem.
	_style_off = StyleBoxFlat.new()
	_style_off.bg_color = Color(0, 0, 0, 0)
	_style_off.border_color = Color(0, 0, 0, 0)
	_style_on = StyleBoxFlat.new()
	_style_on.bg_color = Color(0.35, 0.26, 0.12, 1.0)
	_style_on.border_color = Color(1.0, 0.85, 0.3, 1.0)
	for style in [_style_off, _style_on]:
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(4)
