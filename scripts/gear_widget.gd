class_name GearWidget
extends PanelContainer
## Uma celula da HUD de parabola: nome, valor grande, engrenagem e os
## coeficientes da equacao que ela mexe.
##
## A engrenagem gira enquanto o jogador segura a seta e trava quando o valor bate
## no limite -- a trava e o feedback de "nao da para ir mais longe". Ela tambem
## pode ser agarrada com o mouse: segurando o botao e girando em volta dela, o
## valor acompanha, como uma manivela de verdade.
##
## Os chips "a b c" embaixo sao a ponte com a matematica: dizem em qual numero da
## equacao esta engrenagem mexe. A arena calcula isso perturbando o valor, entao
## o chip e sempre verdadeiro -- com o tanque fora do zero, por exemplo, a forca
## passa a mexer tambem no b e no c.

## Emitido a cada movimento do arrasto, em radianos girados (positivo = horario).
signal dragged(delta_rad: float)
## Emitido quando o jogador agarra a engrenagem, para a HUD selecionar esta celula.
signal grabbed

const HINT_TEXTURE = preload("res://assets/sprites/keyboard_mouse/keyboard_arrows_vertical.png")

const GEAR_SIZE: float = 40.0
const HINT_SIZE: float = 16.0
# Raio, a partir do centro da engrenagem, em que o arrasto circular para de
# responder. Perto do centro o angulo do cursor e instavel.
const DRAG_DEAD_ZONE: float = 10.0
const COEFS := ["a", "b", "c"]

var _title: Label
var _value: Label
var _gear: UiIcon
var _hint: TextureRect
var _chips: Array = []
var _style_on: StyleBox
var _style_off: StyleBox
var _value_color: Color = UiTokens.TEXT
var _flash_tween: Tween
var _dragging: bool = false
var _drag_angle: float = 0.0


func setup(title_text: String, width: float) -> void:
	custom_minimum_size = Vector2(width, 0.0)
	_build_styles()
	add_theme_stylebox_override("panel", _style_off)

	# Engrenagem a esquerda, duas linhas a direita (nome + chips, valor): a
	# celula fica baixa e o painel do topo tapa pouco ceu.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	row.add_child(_build_gear_row())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	_title = Label.new()
	_title.text = title_text.to_upper()
	_title.theme_type_variation = &"CaptionLabel"
	head.add_child(_title)
	head.add_child(_build_chips())

	_value = Label.new()
	_value.text = "--"
	_value.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	_value.add_theme_font_override("font", UiTheme.body_font(UiTokens.WEIGHT_BOLD))
	box.add_child(_value)


func set_title_text(text_value: String) -> void:
	if _title:
		_title.text = text_value.to_upper()


func set_value_text(text_value: String) -> void:
	if _value:
		_value.text = text_value


## Legenda extra foi removida para o painel ficar baixo; mantida como no-op.
func set_caption(_text_value: String) -> void:
	pass


## `letters` = coeficientes que esta engrenagem mexe agora ("a", "ab", "abc").
func set_effects(letters: String) -> void:
	for i in range(_chips.size()):
		var on: bool = letters.contains(COEFS[i])
		var chip: Label = _chips[i]
		chip.visible = on


func set_selected(on: bool) -> void:
	if _value == null:
		return
	add_theme_stylebox_override("panel", _style_on if on else _style_off)
	_value_color = UiTokens.EDITABLE if on else UiTokens.TEXT
	_value.add_theme_color_override("font_color", _value_color)
	_title.add_theme_color_override("font_color", UiTokens.TEXT if on else UiTokens.TEXT_MUTED)
	_gear.color = UiTokens.EDITABLE if on else UiTokens.GEAR_IDLE
	# A dica de tecla so aparece na engrenagem ativa: mostra qual seta age ali,
	# no lugar exato da acao, sem poluir as outras celulas.
	_hint.modulate.a = 1.0 if on else 0.0


func spin(amount: float) -> void:
	if _gear:
		_gear.spin += amount


func flash(color: Color = UiTokens.DANGER) -> void:
	if _value == null:
		return
	# Sem a guarda, segurar a tecla no limite reinicia o tween todo frame e a cor congela.
	if _flash_tween != null and _flash_tween.is_running():
		return
	_value.add_theme_color_override("font_color", color)
	_flash_tween = create_tween()
	_flash_tween.tween_property(
		_value, "theme_override_colors/font_color", _value_color, UiTokens.FLASH_TIME
	)


## Centro da engrenagem em coordenadas globais de tela (para o arrasto).
func gear_center() -> Vector2:
	return _gear.get_global_rect().get_center()


## So inicia o arrasto. O resto vem de _input, porque o gui_input da engrenagem
## para de chegar assim que o cursor sai dela -- e girar em volta dela
## significa justamente sair.
func _on_gear_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	_dragging = true
	# Cresce no sentido horario, porque em Godot 2D o eixo Y aponta para baixo.
	_drag_angle = (event.global_position - gear_center()).angle()
	grabbed.emit()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	# Consulta o estado real do botao em vez de esperar o evento de soltar: se o
	# jogador solta fora da janela, ou durante a pausa, esse evento nunca chega.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
		return
	if not (event is InputEventMouseMotion):
		return

	var offset: Vector2 = event.global_position - gear_center()
	var now: float = offset.angle()
	# wrapf para o salto de +PI para -PI ao cruzar a esquerda nao virar um giro inteiro.
	var step: float = wrapf(now - _drag_angle, -PI, PI)
	# A referencia acompanha o cursor mesmo dentro da zona morta; senao, sair dela
	# produziria de uma vez todo o giro acumulado la dentro.
	_drag_angle = now
	if offset.length() < DRAG_DEAD_ZONE:
		return
	dragged.emit(step)


func _build_gear_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_hint = TextureRect.new()
	_hint.texture = HINT_TEXTURE
	_hint.custom_minimum_size = Vector2(HINT_SIZE, HINT_SIZE)
	_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hint.modulate = Color(UiTokens.EDITABLE, 0.0)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hint)

	_gear = UiIcon.make("gear", UiTokens.GEAR_IDLE, GEAR_SIZE)
	_gear.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_gear.tooltip_text = "Segure e gire como uma manivela"
	_gear.gui_input.connect(_on_gear_gui_input)
	row.add_child(_gear)
	return row


func _build_chips() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for letter in COEFS:
		var chip := Label.new()
		chip.text = letter
		chip.theme_type_variation = &"EditableLabel"
		chip.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
		row.add_child(chip)
		_chips.append(chip)
	return row


func _build_styles() -> void:
	# Os dois estilos tem as MESMAS margens: sem isso a celula muda de tamanho ao
	# ser selecionada e o HBox inteiro treme a cada troca de engrenagem. O
	# desligado e a mesma moldura com todas as cores transparentes.
	_style_on = UiPanel.create(UiPanel.Kind.SELECTED)
	var off: UiFrame = _style_on.duplicate()
	for prop in ["fill", "outline", "border", "bevel_light", "bevel_dark"]:
		off.set(prop, UiTokens.TRANSPARENT)
	_style_off = off
