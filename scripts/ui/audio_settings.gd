class_name AudioSettingsPanel
extends VBoxContainer
## Os tres controles de volume, compartilhados entre o menu principal e a pausa.
##
## Antes existiam so no menu_play e escreviam todos no mesmo bus: o projeto nao
## tinha bus layout, so o Master, e o fallback mandava "Efeitos Sonoros" e
## "Trilha Sonora" para la. Mexer em um mexia nos tres. Agora BGM e SFX existem
## de verdade (default_bus_layout.tres) e cada slider governa o seu.
##
## O bus e a unica fonte de verdade do volume. Ter tambem variaveis de mix no
## AudioManager multiplicaria em serie -- dois estagios em 0.5 dao 25%, nao 50%.

const ROWS := [
	{"label": "Volume Geral", "bus": "Master"},
	{"label": "Efeitos Sonoros", "bus": "SFX"},
	{"label": "Trilha Sonora", "bus": "BGM"},
]


func _ready() -> void:
	add_theme_constant_override("separation", UiTokens.GAP)
	for row in ROWS:
		add_child(_build_row(row["label"], row["bus"]))


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
