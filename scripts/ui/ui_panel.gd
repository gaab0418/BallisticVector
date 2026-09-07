class_name UiPanel
extends RefCounted
## Fabrica de StyleBoxFlat para as superficies do jogo.
##
## Substitui os doze StyleBoxFlat construidos a mao no war_map.gd e o
## _create_steampunk_panel() da arena, incluindo o bloco que estava duplicado
## literalmente entre o card de municao e o card do kit de reparo.

enum Kind {
	PANEL,  # painel de conteudo comum (menu, hud)
	MODAL,  # janela sobreposta, borda mais clara
	CARD,  # item dentro de uma lista, borda fina
	HUD,  # faixa translucida sobre o gameplay
}


## Aplica o mesmo valor aos quatro lados. StyleBoxFlat nao tem setter unico para
## isso, e repetir quatro linhas em cada estilo era metade do ruido do codigo
## de UI antigo.
static func set_border(box: StyleBoxFlat, width: int, color: Color) -> void:
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width
	box.border_color = color


static func set_radius(box: StyleBoxFlat, radius: int) -> void:
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius


static func set_margin(box: StyleBoxFlat, margin: int) -> void:
	box.content_margin_left = margin
	box.content_margin_top = margin
	box.content_margin_right = margin
	box.content_margin_bottom = margin


static func create(kind: int = Kind.PANEL) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()

	match kind:
		Kind.MODAL:
			box.bg_color = UiTokens.BG_MODAL
			set_border(box, UiTokens.BORDER_W_THIN, UiTokens.BORDER_MODAL)
			set_radius(box, UiTokens.RADIUS_LG)
			set_margin(box, UiTokens.PAD_LG)
			box.shadow_color = UiTokens.SHADOW
			box.shadow_size = UiTokens.SHADOW_SIZE
		Kind.CARD:
			box.bg_color = UiTokens.BG_CARD
			set_border(box, 1, UiTokens.BORDER_PRESSED)
			set_radius(box, UiTokens.RADIUS)
			set_margin(box, UiTokens.PAD)
		Kind.HUD:
			box.bg_color = UiTokens.BG_HUD
			set_border(box, UiTokens.BORDER_W_THIN, UiTokens.BORDER)
			set_radius(box, UiTokens.RADIUS)
			set_margin(box, UiTokens.PAD_SM)
		_:
			box.bg_color = UiTokens.BG_PANEL
			set_radius(box, UiTokens.RADIUS_LG)
			set_margin(box, UiTokens.PAD_LG)

	return box
