class_name StageBriefing
extends UiModal
## Cartao de missao no inicio de cada fase: o que a fase ensina, uma dica e os
## tres desafios que valem estrelas.

const PANEL_SIZE := Vector2(640, 0)

var _chapter: Label
var _title: Label
var _lesson: Label
var _tip: Label
var _goals: VBoxContainer
var _start: Button


func _build_content() -> void:
	pauses_game = true
	window.custom_minimum_size = PANEL_SIZE
	title_label.visible = false

	_chapter = Label.new()
	_chapter.theme_type_variation = &"CaptionLabel"
	_chapter.add_theme_color_override("font_color", UiTokens.BRASS)
	body.add_child(_chapter)

	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.add_theme_font_size_override("font_size", UiTokens.FONT_DISPLAY)
	body.add_child(_title)

	_lesson = Label.new()
	_lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lesson.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	_lesson.custom_minimum_size = Vector2(580, 0)
	body.add_child(_lesson)

	var tip_row := HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", 8)
	tip_row.add_child(UiIcon.make("target", UiTokens.CALCULATED, 22.0))
	_tip = Label.new()
	_tip.theme_type_variation = &"ResultLabel"
	_tip.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_row.add_child(_tip)
	body.add_child(tip_row)

	body.add_child(HSeparator.new())

	var head := Label.new()
	head.text = "GANHE ESTRELAS"
	head.theme_type_variation = &"CaptionLabel"
	body.add_child(head)
	_goals = VBoxContainer.new()
	_goals.add_theme_constant_override("separation", 6)
	body.add_child(_goals)

	_start = UiButton.create("COMEÇAR!", UiButton.Kind.PRIMARY, null, true)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.pressed.connect(close)
	body.add_child(_start)


## `states`/`progress` vazios = inicio da fase. Preenchidos = reaberto pelo
## botao de estrela no meio da luta, mostrando o que ja foi cumprido.
func show_stage(
	base_name: String,
	chapter: String,
	number: int,
	stage: Dictionary,
	states: Array = [],
	progress: Array = []
) -> void:
	var reopened := not states.is_empty()
	_chapter.text = "%s  ·  %s  ·  FASE %d" % [base_name.to_upper(), chapter.to_upper(), number]
	_title.text = stage.title
	_lesson.text = stage.lesson
	_tip.text = stage.tip
	_start.text = "CONTINUAR" if reopened else "COMEÇAR!"
	for child in _goals.get_children():
		child.queue_free()
	_goals.add_child(_row("Destrua o castelo inimigo", -1, ""))
	for i in range(stage.goals.size()):
		var st: int = states[i] if reopened else -1
		var extra: String = progress[i] if reopened and i < progress.size() else ""
		_goals.add_child(_row(Campaign.goal_text(stage.goals[i]), st, extra))
	open()
	# Pop de entrada: a janela cresce do centro.
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2(0.85, 0.85)
	var tw := window.create_tween()
	tw.tween_property(window, "scale", Vector2.ONE, UiTokens.ANIM).set_trans(Tween.TRANS_BACK)
	_start.grab_focus.call_deferred()


## `state` -1 = ainda nao comecou (estrela vazia). Senao, StageGoals.State.
func _row(text: String, state: int, extra: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := "star_empty"
	var col := UiTokens.EDITABLE
	var text_col := UiTokens.TEXT
	match state:
		StageGoals.State.DONE:
			icon = "star"
		StageGoals.State.FAILED:
			icon = "cross"
			col = UiTokens.TEXT_DISABLED
			text_col = UiTokens.TEXT_DISABLED
	row.add_child(UiIcon.make(icon, col, 24.0))
	var label := Label.new()
	label.text = text + (("   " + extra) if extra != "" else "")
	label.add_theme_color_override("font_color", text_col)
	row.add_child(label)
	return row
