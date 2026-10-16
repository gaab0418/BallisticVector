extends Node
## Laboratorio: modo livre da arena, sem inimigos e com municao infinita.
##
## Liga o LabPanel ao combate: troca de mundo, alvo clicavel e a tabela de pontos
## do ultimo tiro. A arena continua cuidando de engrenagens, curva e disparo.

const TARGET_HIT_M := 0.5

var arena: Node2D
var panel: LabPanel
var _target := Vector2.INF
var _marker: Node2D
var _proj: Node2D
var _shot: Dictionary = {}
var _next_x := 1
var _hit_announced := false


func setup(host: Node2D) -> void:
	arena = host
	panel = LabPanel.new()
	host.add_child(panel)
	panel.world_chosen.connect(_on_world)
	panel.clear_pressed.connect(_clear)
	panel.exit_pressed.connect(_exit)
	_marker = Node2D.new()
	_marker.z_index = 4
	_marker.draw.connect(_draw_marker)
	host.add_child(_marker)


func _on_world(key: String) -> void:
	Global.lab_world = key
	arena.get_tree().reload_current_scene()


func _exit() -> void:
	Global.lab_mode = false
	arena.get_tree().paused = false
	arena.get_tree().change_scene_to_file("res://scenes/menu_play/menu_play.tscn")


func _clear() -> void:
	panel.clear_rows()
	_target = Vector2.INF
	panel.set_target_text("")
	_marker.queue_redraw()


## A arena chama ao disparar: a tabela recomeca para o tiro novo.
func on_fired(projectile: Node2D) -> void:
	_proj = projectile
	_shot = projectile.get_meta("shot")
	_next_x = int(ceil(_shot.x_tank + 0.001))
	_hit_announced = false
	panel.clear_rows()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or arena.get_tree().paused:
		return
	var p: Vector2 = arena.get_global_mouse_position()
	if p.y >= Campaign.GROUND_Y or panel.panel_rect().has_point(event.position):
		return
	_target = p
	_marker.queue_redraw()
	refresh_target(arena.current_shot())


## Distancia da curva atual ate o alvo, escrita em linguagem de crianca.
func refresh_target(s: Dictionary) -> void:
	if _target == Vector2.INF or s.is_empty():
		return
	var tx := Ballistics.to_m(_target.x - Campaign.ORIGIN_X)
	var ty := Ballistics.to_m(Campaign.GROUND_Y - _target.y)
	var best := INF
	var x: float = s.x_tank
	while x < tx + 6.0:
		var d := Vector2(x, Ballistics.y_at(s, x)).distance_to(Vector2(tx, ty))
		best = minf(best, d)
		x += 0.05
	var where := "Alvo em (%s ; %s)" % [Ballistics.fmt(tx), Ballistics.fmt(ty)]
	var verdict := (
		"a curva passa pelo alvo!"
		if best < TARGET_HIT_M
		else "a curva passa a %s m" % Ballistics.fmt(best)
	)
	panel.set_target_text(where + "\n" + verdict)


func _process(_delta: float) -> void:
	if _proj == null or not is_instance_valid(_proj) or _shot.is_empty():
		return
	var xm := Ballistics.to_m(_proj.position.x - Campaign.ORIGIN_X)
	while xm >= _next_x:
		var yb := Ballistics.to_m(Campaign.GROUND_Y - _proj.position.y)
		panel.add_row(_next_x, yb, Ballistics.y_at(_shot, _next_x), arena.trajectory.aim)
		_next_x += 1
	if _target != Vector2.INF and not _hit_announced:
		if _proj.position.distance_to(_target) < Ballistics.to_px(TARGET_HIT_M):
			_hit_announced = true
			arena.hud.show_toast("Na mosca!", UiTokens.EDITABLE)
			ArenaFx.spawn(arena, _target, ArenaFx.Kind.SPARK)


func _draw_marker() -> void:
	if _target == Vector2.INF:
		return
	var t := _target
	var col := UiTokens.EDITABLE
	_marker.draw_arc(t, 14.0, 0, TAU, 20, UiTokens.AIM_OUTLINE, 6.0)
	_marker.draw_arc(t, 14.0, 0, TAU, 20, col, 3.0)
	_marker.draw_line(t + Vector2(-20, 0), t + Vector2(20, 0), col, 2.0)
	_marker.draw_line(t + Vector2(0, -20), t + Vector2(0, 20), col, 2.0)
	_marker.draw_dashed_line(t, Vector2(t.x, Campaign.GROUND_Y), Color(col, 0.5), 2.0, 6.0)
