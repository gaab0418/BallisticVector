@tool
class_name UiFrame
extends StyleBox
## Moldura em pixel art, desenhada so com retangulos: sai nitida com qualquer
## filtro de textura e escala de janela.
##
## Camadas, de fora para dentro, cada uma com `unit` pixels de espessura:
##   sombra dura (deslocada para baixo) -> contorno escuro -> anel de latao com
##   bisel (claro em cima, escuro embaixo) -> miolo.
## Os cantos sao chanfrados em um pixel.
##
## @tool porque o editor tambem desenha o Theme.
##
## Nao referencia nenhuma outra classe global (nem UiTokens): este script e
## carregado junto com o tema do projeto, antes de o Godot registrar as classes
## numa importacao do zero. Os valores sempre vem de UiPanel.frame().

@export var fill: Color
@export var draw_fill := true
@export var outline: Color
@export var border: Color
## Espessura do anel de latao, em unidades.
@export var border_units := 1
@export var bevel_light: Color
@export var bevel_dark: Color
## Inverte o bisel: claro embaixo, escuro em cima. E o estado "afundado".
@export var inset := false
@export var shadow: Color
## Deslocamento da sombra dura, em unidades. 0 = sem sombra.
@export var shadow_units := 0
@export var rivets := false
@export var rivet_color: Color
## Desenha so um anel na cor `border`, por fora do retangulo. Usado no foco,
## que o Godot pinta por cima do estilo normal.
@export var ring_only := false
## Tamanho do pixel da moldura, em pixels de tela.
@export var unit: int = 1


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var u := float(unit)
	var r := Rect2(rect.position.round(), rect.size.round())

	if ring_only:
		_ring(to_canvas_item, r.grow(u), u, border)
		return

	if shadow_units > 0:
		_chamfer(
			to_canvas_item, Rect2(r.position + Vector2(0, shadow_units * u), r.size), u, shadow
		)

	_chamfer(to_canvas_item, r, u, outline)

	var ring := r.grow(-u)
	if ring.size.x <= 2.0 * u or ring.size.y <= 2.0 * u:
		return
	_chamfer(to_canvas_item, ring, u, border)
	_bevel(to_canvas_item, ring, u)

	var inner := ring.grow(-u * border_units)
	if draw_fill and inner.size.x > 0.0 and inner.size.y > 0.0:
		RenderingServer.canvas_item_add_rect(to_canvas_item, inner, fill)

	if rivets:
		_rivets(to_canvas_item, ring, u)


## Retangulo com os quatro cantos cortados em `u`: a uniao de uma faixa
## horizontal e uma vertical.
func _chamfer(ci: RID, r: Rect2, u: float, color: Color) -> void:
	if color.a <= 0.0:
		return
	RenderingServer.canvas_item_add_rect(
		ci, Rect2(r.position.x + u, r.position.y, r.size.x - 2.0 * u, r.size.y), color
	)
	RenderingServer.canvas_item_add_rect(
		ci, Rect2(r.position.x, r.position.y + u, u, r.size.y - 2.0 * u), color
	)
	RenderingServer.canvas_item_add_rect(
		ci, Rect2(r.end.x - u, r.position.y + u, u, r.size.y - 2.0 * u), color
	)


## Anel de espessura `u` com cantos chanfrados, sem miolo.
func _ring(ci: RID, r: Rect2, u: float, color: Color) -> void:
	var w := r.size.x
	var h := r.size.y
	var p := r.position
	RenderingServer.canvas_item_add_rect(ci, Rect2(p.x + u, p.y, w - 2.0 * u, u), color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(p.x + u, r.end.y - u, w - 2.0 * u, u), color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(p.x, p.y + u, u, h - 2.0 * u), color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(r.end.x - u, p.y + u, u, h - 2.0 * u), color)


## Linha clara no topo e escura na base do anel de latao: da volume ao metal.
func _bevel(ci: RID, ring: Rect2, u: float) -> void:
	var top := bevel_dark if inset else bevel_light
	var bottom := bevel_light if inset else bevel_dark
	var x := ring.position.x + u
	var w := ring.size.x - 2.0 * u
	RenderingServer.canvas_item_add_rect(ci, Rect2(x, ring.position.y, w, u), top)
	RenderingServer.canvas_item_add_rect(ci, Rect2(x, ring.end.y - u, w, u), bottom)


## Rebites nos quatro cantos do anel. So cabem com anel de 2 unidades ou mais.
func _rivets(ci: RID, ring: Rect2, u: float) -> void:
	if border_units < 2 or ring.size.x < 12.0 * u or ring.size.y < 12.0 * u:
		return
	var s := u * border_units
	var corners := [
		ring.position + Vector2(2.0 * u, 0.0),
		Vector2(ring.end.x - 2.0 * u - s, ring.position.y),
		Vector2(ring.position.x + 2.0 * u, ring.end.y - s),
		ring.end - Vector2(2.0 * u + s, s),
	]
	for c in corners:
		RenderingServer.canvas_item_add_rect(ci, Rect2(c, Vector2(s, s)), bevel_dark)
		RenderingServer.canvas_item_add_rect(ci, Rect2(c, Vector2(s - u, s - u)), rivet_color)
