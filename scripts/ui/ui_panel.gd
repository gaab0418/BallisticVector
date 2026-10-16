class_name UiPanel
extends RefCounted
## Fabrica das superficies do jogo: todas sao molduras UiFrame em pixel art.
##
## Substitui os doze StyleBoxFlat construidos a mao no war_map.gd e o
## _create_steampunk_panel() da arena. Toda tela pede um Kind daqui em vez de
## montar o proprio estilo.

enum Kind {
	PANEL,  # painel de conteudo comum (menu)
	MODAL,  # janela sobreposta: anel de latao grosso com rebites
	CARD,  # item dentro de uma lista, moldura discreta
	HUD,  # faixa translucida sobre o gameplay
	PAPER,  # papel envelhecido com tinta: diagrama da ajuda, cartao do mapa
	SELECTED,  # celula escolhida (engrenagem ativa): anel ambar
}


## Ainda usados por slider, barra de progresso e celulas de engrenagem, que
## seguem em StyleBoxFlat porque sao faixas simples, sem moldura.
static func set_border(box: StyleBoxFlat, width: int, color: Color) -> void:
	box.set_border_width_all(width)
	box.border_color = color


static func set_radius(box: StyleBoxFlat, radius: int) -> void:
	box.set_corner_radius_all(radius)


static func set_margin(box: StyleBox, margin: int) -> void:
	box.set_content_margin_all(margin)


## Moldura base. `pad` e o respiro entre a moldura e o conteudo; a espessura da
## propria moldura e somada aqui para o conteudo nunca encostar no latao.
static func frame(
	fill: Color, border: Color, border_units: int = 1, pad: int = UiTokens.PAD
) -> UiFrame:
	var box := UiFrame.new()
	box.unit = UiTokens.PX
	box.fill = fill
	box.outline = UiTokens.NIGHT_950
	box.border = border
	box.border_units = border_units
	box.bevel_light = UiTokens.BEVEL_LIGHT
	box.bevel_dark = UiTokens.BEVEL_DARK
	box.shadow = UiTokens.SHADOW
	box.rivet_color = UiTokens.BRASS_LIGHT
	box.set_content_margin_all(UiTokens.PX * (1 + border_units) + pad)
	return box


static func create(kind: int = Kind.PANEL) -> UiFrame:
	match kind:
		Kind.MODAL:
			var box := frame(UiTokens.BG_MODAL, UiTokens.BORDER_MODAL, 3, UiTokens.PAD_LG)
			box.rivets = true
			box.shadow_units = 3
			return box
		Kind.CARD:
			return frame(UiTokens.BG_CARD, UiTokens.BORDER_PRESSED, 1, UiTokens.PAD_SM + 4)
		Kind.HUD:
			return frame(UiTokens.BG_HUD, UiTokens.BORDER, 1, UiTokens.PAD_SM)
		Kind.PAPER:
			var paper := frame(UiTokens.PAPER, UiTokens.PAPER_DARK, 2, UiTokens.PAD)
			paper.outline = UiTokens.INK
			return paper
		Kind.SELECTED:
			var sel := frame(UiTokens.BG_SELECTED, UiTokens.EDITABLE, 1, 4)
			sel.bevel_light = UiTokens.TRANSPARENT
			return sel
		_:
			var panel := frame(UiTokens.BG_PANEL, UiTokens.BORDER, 2, UiTokens.PAD_LG)
			panel.rivets = true
			panel.shadow_units = 2
			return panel
