class_name StageResult
extends UiModal
## Tela de fim de fase: as estrelas ganhas aparecem uma a uma, cada desafio com
## o seu resultado, e o ouro recebido.

signal next_requested
signal map_requested

const PANEL_SIZE := Vector2(560, 0)
const STAR_SIZE := 64.0

var _headline: Label
var _ada: AdaPortrait
var _ada_line: Label
var _stars_row: HBoxContainer
var _goals: VBoxContainer
var _reward: Label
var _next: Button
var _map: Button


func _build_content() -> void:
	pauses_game = true
	close_on_escape = false
	window.custom_minimum_size = PANEL_SIZE
	title_label.visible = false

	_headline = Label.new()
	_headline.theme_type_variation = &"DisplayLabel"
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_headline)

	_stars_row = HBoxContainer.new()
	_stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars_row.add_theme_constant_override("separation", 18)
	body.add_child(_stars_row)

	_goals = VBoxContainer.new()
	_goals.add_theme_constant_override("separation", 6)
	body.add_child(_goals)

	# A Ada comenta o resultado: uma frase, conforme as estrelas.
	var ada_row := HBoxContainer.new()
	ada_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ada_row.add_theme_constant_override("separation", 10)
	body.add_child(ada_row)
	_ada = AdaPortrait.new()
	_ada.custom_minimum_size = Vector2(64, 64)
	ada_row.add_child(_ada)
	_ada_line = Label.new()
	_ada_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ada_line.custom_minimum_size = Vector2(380, 0)
	_ada_line.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
	ada_row.add_child(_ada_line)

	_reward = Label.new()
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward.add_theme_color_override("font_color", UiTokens.GOLD)
	_reward.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	body.add_child(_reward)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTokens.GAP)
	body.add_child(row)

	_map = UiButton.create("VOLTAR AO MAPA", UiButton.Kind.SECONDARY, null, true)
	_map.custom_minimum_size = Vector2(230, 52)
	_map.pressed.connect(func(): map_requested.emit())
	row.add_child(_map)

	_next = UiButton.create("PRÓXIMA FASE", UiButton.Kind.PRIMARY, null, true)
	_next.custom_minimum_size = Vector2(230, 52)
	_next.pressed.connect(func(): next_requested.emit())
	row.add_child(_next)


func show_result(stars: int, goals: Array, states: Array, gold: int, last_stage: bool) -> void:
	_headline.text = "BASE CONQUISTADA!" if last_stage else "FASE VENCIDA!"
	_next.visible = not last_stage
	_reward.text = "+%d de ouro  ·  +%d de latão para a Oficina" % [gold, Global.BRASS_PER_WIN]
	var page := Notebook.page_for(Global.current_base_id, Global.current_stage)
	if not page.is_empty() and not Global.notebook_seen.has(Notebook.page_id(page)):
		_reward.text += '\nNova página no Caderno da Ada: "%s"' % page.title
	var says := [
		"Vitória! Tente os desafios para ganhar mais estrelas.",
		"Muito bem! Falta pouco para as três estrelas.",
		"Perfeito! Você domina essa ideia, recruta.",
	]
	_ada_line.text = "“" + says[clampi(stars - 1, 0, 2)] + "”"
	_ada.expression = "proud" if stars >= 3 else "happy"

	for child in _stars_row.get_children():
		child.queue_free()
	var star_nodes := []
	for i in range(3):
		var star := UiIcon.make("star" if i < stars else "star_empty", UiTokens.EDITABLE, STAR_SIZE)
		star.modulate.a = 0.0
		_stars_row.add_child(star)
		star_nodes.append(star)

	for child in _goals.get_children():
		child.queue_free()
	_goals.add_child(_row(true, "Destrua o castelo inimigo"))
	for i in range(goals.size()):
		_goals.add_child(_row(states[i] == StageGoals.State.DONE, Campaign.goal_text(goals[i])))

	open()
	(_next if not last_stage else _map).grab_focus.call_deferred()
	# Estrelas entram uma por uma, com um pulo -- as ganhas maiores que as vazias.
	var tw := create_tween()
	for i in range(3):
		var node: UiIcon = star_nodes[i]
		tw.tween_callback(func(): node.pivot_offset = node.size * 0.5)
		tw.tween_property(node, "modulate:a", 1.0, 0.01)
		node.scale = Vector2(0.2, 0.2)
		var peak := 1.3 if i < stars else 1.0
		tw.tween_property(node, "scale", Vector2(peak, peak), 0.16).set_trans(Tween.TRANS_BACK)
		tw.tween_property(node, "scale", Vector2.ONE, 0.1)
		if i < stars:
			tw.tween_callback(func(): UiButton._play(node, UiButton.SFX_CLICK))


func _row(ok: bool, text: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(
		UiIcon.make(
			"check" if ok else "cross", UiTokens.SUCCESS if ok else UiTokens.TEXT_DISABLED, 22.0
		)
	)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiTokens.TEXT if ok else UiTokens.TEXT_DISABLED)
	row.add_child(label)
	return row
