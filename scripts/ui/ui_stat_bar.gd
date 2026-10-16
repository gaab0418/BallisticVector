class_name UiStatBar
extends HBoxContainer
## Barra com icone e numero: "escudo  ████░░  80/100".
##
## A barra de Blindagem antiga nao tinha valor numerico, e a informacao ficava
## so na cor e no comprimento. Aqui o numero vem escrito dentro da barra, o
## icone diz do que se trata e, abaixo de LOW_RATIO, a barra muda para a cor de
## perigo -- tres sinais, nenhum dependendo so de cor.

const LOW_RATIO := 0.35

var _icon: UiIcon
var _bar: ProgressBar
var _value: Label
var _fill_ok: StyleBoxFlat
var _fill_low: StyleBoxFlat
var _last := -1.0


func setup(icon_name: String, bar_size: Vector2) -> void:
	add_theme_constant_override("separation", UiTokens.GAP_SM)
	alignment = BoxContainer.ALIGNMENT_CENTER

	_icon = UiIcon.make(icon_name, UiTokens.ARMOR_FILL, 26.0)
	add_child(_icon)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = bar_size
	_bar.show_percentage = false
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_bar)

	_fill_ok = _fill(UiTokens.ARMOR_FILL)
	_fill_low = _fill(UiTokens.ARMOR_LOW)
	_bar.add_theme_stylebox_override("fill", _fill_ok)

	_value = Label.new()
	_value.theme_type_variation = &"OverlayLabel"
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar.add_child(_value)
	_value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_value(value: float, max_value: float) -> void:
	if _bar == null:
		return
	_bar.max_value = max_value
	_bar.value = value
	_value.text = "%d/%d" % [roundi(value), roundi(max_value)]
	var low := value / maxf(max_value, 1.0) < LOW_RATIO
	_bar.add_theme_stylebox_override("fill", _fill_low if low else _fill_ok)
	_icon.color = UiTokens.ARMOR_LOW if low else UiTokens.ARMOR_FILL
	# Caiu: pisca o icone e o numero. Subir (reparo) nao precisa de alarme.
	if _last >= 0.0 and value < _last:
		_flash()
	_last = value


func _flash() -> void:
	_value.modulate = UiTokens.HIT_FLASH
	var tw := create_tween()
	tw.tween_property(_value, "modulate", UiTokens.NO_TINT, UiTokens.FLASH_TIME)
	var tw2 := create_tween()
	tw2.tween_property(_icon, "scale", Vector2(1.35, 1.35), UiTokens.ANIM_FAST)
	tw2.tween_property(_icon, "scale", Vector2.ONE, UiTokens.ANIM)
	_icon.pivot_offset = _icon.size * 0.5


func _fill(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.anti_aliasing = false
	box.set_border_width_all(UiTokens.PX)
	box.border_color = UiTokens.TRANSPARENT
	return box
