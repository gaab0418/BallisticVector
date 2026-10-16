extends SceneTree
## Compila o Theme do jogo para assets/resources/ui_theme.tres.
##
## Rode sempre que UiTokens ou UiTheme mudarem:
##
##     godot --headless --script res://tools/build_ui_theme.gd
##
## O .tres e registrado em project.godot (gui/theme/custom) porque CanvasLayer
## interrompe a heranca de tema; detalhes em scripts/ui/ui_theme.gd.

const OUT_PATH := "res://assets/resources/ui_theme.tres"


func _initialize() -> void:
	var theme := UiTheme.build()
	var status := ResourceSaver.save(theme, OUT_PATH)
	if status != OK:
		push_error("Falha ao salvar %s (erro %d)" % [OUT_PATH, status])
		quit(1)
		return
	print("Theme compilado em ", OUT_PATH)
	quit(0)
