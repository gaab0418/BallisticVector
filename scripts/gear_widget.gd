class_name GearWidget
extends PanelContainer
## Uma célula da HUD de parábola: título pequeno em cima, valor grande no meio e uma
## engrenagem embaixo, que é ao mesmo tempo indicador e controle.
##
## A engrenagem gira enquanto o jogador segura a seta e trava quando o valor bate no
## limite — a trava é o feedback de "não dá para ir mais longe". Ela também pode ser
## agarrada com o mouse: segurando o botão e girando em volta dela, o valor acompanha,
## como uma manivela de verdade.

## Emitido a cada movimento do arrasto, em radianos girados (positivo = horário).
signal dragged(delta_rad: float)
## Emitido quando o jogador agarra a engrenagem, para a HUD selecionar esta célula.
signal grabbed

const GEAR_TEXTURE = preload("res://assets/sprites/icons/gear_white.png")
const HINT_TEXTURE = preload("res://assets/sprites/keyboard_mouse/keyboard_arrows_vertical.png")

const GEAR_SIZE: float = 46.0
# Um quadrado girado ocupa lado * sqrt(2). Sem esta folga os cantos da engrenagem
# seriam cortados ao girar.
const GEAR_BOX: float = 66.0
const HINT_SIZE: float = 26.0
const FLASH_TIME: float = 0.35

const COLOR_VALUE_ON := Color(1.0, 0.85, 0.3)
const COLOR_VALUE_OFF := Color(0.9, 0.8, 0.6)
const COLOR_TITLE_ON := Color(0.9, 0.8, 0.6)
const COLOR_TITLE_OFF := Color(0.75, 0.62, 0.42)
const COLOR_GEAR_ON := Color(1.0, 0.85, 0.3)
const COLOR_GEAR_OFF := Color(0.5, 0.42, 0.3)
const COLOR_ALERT := Color(1.0, 0.2, 0.2)

var _title: Label
var _value: Label
var _gear: TextureRect
var _hint: TextureRect
var _slot: Control
var _style_on: StyleBoxFlat
var _style_off: StyleBoxFlat
var _value_color: Color = COLOR_VALUE_OFF
var _flash_tween: Tween
var _dragging: bool = false
var _drag_angle: float = 0.0


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
	# A dica de tecla só aparece na engrenagem ativa: mostra qual seta age ali, no
	# lugar exato da ação, sem poluir as outras células.
	_hint.visible = on


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


## Só inicia o arrasto. O resto vem de _input, porque o gui_input do slot para de
## chegar assim que o cursor sai dos 66 px da engrenagem — e girar em volta dela
## significa justamente sair.
func _on_gear_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	_dragging = true
	_drag_angle = _angle_from_gear(event.global_position)
	grabbed.emit()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	# Consulta o estado real do botão em vez de esperar o evento de soltar: se o jogador
	# solta fora da janela, ou durante a pausa da tela de ajuda, esse evento nunca chega
	# e o arrasto ficaria grudado no cursor.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
		return
	if not (event is InputEventMouseMotion):
		return

	var now: float = _angle_from_gear(event.global_position)
	# wrapf para o salto de +PI para -PI ao cruzar a esquerda não virar um giro inteiro.
	var step: float = wrapf(now - _drag_angle, -PI, PI)
	_drag_angle = now
	dragged.emit(step)


## Ângulo do cursor em volta do centro da engrenagem. Cresce no sentido horário,
## porque em Godot 2D o eixo Y aponta para baixo.
func _angle_from_gear(global_pos: Vector2) -> float:
	return (global_pos - _gear.get_global_rect().get_center()).angle()


func _build_gear_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_hint = TextureRect.new()
	_hint.texture = HINT_TEXTURE
	_hint.custom_minimum_size = Vector2(HINT_SIZE, HINT_SIZE)
	_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hint.modulate = COLOR_GEAR_ON
	_hint.visible = false
	row.add_child(_hint)

	# Control solto: o HBox dimensiona o slot, e a engrenagem gira dentro dele sem
	# empurrar o layout a cada frame.
	_slot = Control.new()
	_slot.custom_minimum_size = Vector2(GEAR_BOX, GEAR_BOX)
	_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	_slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_slot.gui_input.connect(_on_gear_gui_input)
	row.add_child(_slot)

	_gear = TextureRect.new()
	_gear.texture = GEAR_TEXTURE
	_gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gear.modulate = COLOR_GEAR_OFF
	_slot.add_child(_gear)
	# Depois do add_child: entrar na árvore pode reescrever estes valores.
	_gear.size = Vector2(GEAR_SIZE, GEAR_SIZE)
	_gear.position = Vector2((GEAR_BOX - GEAR_SIZE) * 0.5, (GEAR_BOX - GEAR_SIZE) * 0.5)
	# Literal de propósito: size ainda pode ser (0, 0) antes do primeiro passo de layout,
	# e pivot_offset = size / 2 giraria a engrenagem em torno do canto.
	_gear.pivot_offset = Vector2(GEAR_SIZE * 0.5, GEAR_SIZE * 0.5)

	# Espaçador espelhando a dica, para a engrenagem ficar centrada na célula com ou
	# sem ela visível.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(HINT_SIZE, 0.0)
	row.add_child(spacer)
	return row


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
