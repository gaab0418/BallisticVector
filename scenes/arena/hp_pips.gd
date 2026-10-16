extends Node2D
## Vida de um inimigo em escudinhos, flutuando acima dele. Le o hp do pai:
## meta "hp" (castelo, baloes, bunker) ou propriedade `hp` (avioes, tanques).

const PIP := 14.0
const GAP := 4.0

var max_hp := 1
var offset_y := -60.0


func _ready() -> void:
	z_index = 4
	position = Vector2(0, offset_y)
	max_hp = maxi(1, _hp())


func _process(_delta: float) -> void:
	queue_redraw()


func _hp() -> int:
	var host := get_parent()
	if host == null:
		return 0
	if host.has_meta("hp"):
		return int(host.get_meta("hp"))
	return int(host.get("hp")) if host.get("hp") != null else 0


func _draw() -> void:
	var hp := _hp()
	var total := max_hp * PIP + (max_hp - 1) * GAP
	var x := -total * 0.5
	for i in range(max_hp):
		var icon_name := "shield" if i < hp else "cross"
		var col := UiTokens.DANGER if i < hp else Color(UiTokens.TEXT_DISABLED, 0.8)
		UiIcon.paint(self, icon_name, Rect2(Vector2(x, -PIP * 0.5), Vector2(PIP, PIP)), col)
		x += PIP + GAP
