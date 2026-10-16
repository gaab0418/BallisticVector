class_name AudioSettingsPanel
extends VBoxContainer
## Os tres controles de volume (Master, SFX, BGM) e as opcoes de leitura
## (narracao e texto grande), usados no menu e na pausa.
##
## O bus e a unica fonte de verdade do volume: variaveis de mix no AudioManager
## multiplicariam em serie (0.5 x 0.5 = 25%).

const ROWS := [
	{"label": "Volume Geral", "bus": "Master"},
	{"label": "Efeitos Sonoros", "bus": "SFX"},
	{"label": "Trilha Sonora", "bus": "BGM"},
]


func _ready() -> void:
	add_theme_constant_override("separation", UiTokens.GAP)
	for row in ROWS:
		add_child(_build_row(row["label"], row["bus"]))
	var speak := _toggle("Narrar as falas da Ada", Global.narration, func(on: bool): Global.narration = on)
	if not Narrator.available():
		speak.disabled = true
		speak.tooltip_text = "Este computador não tem uma voz em português instalada"
	add_child(speak)
	add_child(_toggle("Texto grande nas falas e no caderno", Global.big_text, func(on: bool): Global.big_text = on))


func _toggle(text: String, on: bool, apply: Callable) -> CheckButton:
	var b := CheckButton.new()
	b.text = text
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	b.toggled.connect(
		func(value: bool):
			apply.call(value)
			Global.save_game()
	)
	return b


func _build_row(text: String, bus_name: String) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	label.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	column.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(320, 0)
	# Sem isto, clicar no slider daria foco a ele e as setas virariam ajuste de
	# volume em vez de gameplay quando a pausa fechasse.
	slider.focus_mode = Control.FOCUS_NONE

	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		# Defensivo: se alguem remover o bus layout, o controle vira inerte em
		# vez de derrubar a cena com indice -1.
		slider.editable = false
		column.add_child(slider)
		return column

	slider.value = db_to_linear(AudioServer.get_bus_volume_db(index))
	slider.value_changed.connect(
		func(value: float): AudioServer.set_bus_volume_db(index, linear_to_db(value))
	)
	column.add_child(slider)
	return column
