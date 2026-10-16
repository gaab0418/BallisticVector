class_name FormulaDrawer
extends PanelContainer
## "Ver conta": a gaveta de papel embaixo do painel da parabola, com de onde
## saem a, b, c, o vertice e a raiz -- os numeros da tela ja colocados na formula.
##
## Fica escondida por padrao para nao poluir a arena: e apoio para quem quer ver
## a conta (ou para o professor mostrar a turma). Abre com F ou pelo botao.
##
## Usa as formulas de funcao quadratica da escola (vertice -b/2a, Bhaskara) e,
## escreve "delta" e "/" por extenso: no Handjet o Δ parece um 0 e o ÷ pequeno
## parece um +, e numa conta isso engana.
##
## numa linha menor, as formulas de fisica do lancamento obliquo.

var _body: RichTextLabel
## Cor dos numeros calculados, ja escurecida para o papel. Segue a cor "aim" do
## mundo, a mesma da curva e do painel.
var _calc_on_paper: Color = UiTokens.CALCULATED_ON_PAPER
var _height_line := NAN


func _ready() -> void:
	add_theme_stylebox_override("panel", UiPanel.create(UiPanel.Kind.PAPER))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)

	var title := Label.new()
	title.text = "A CONTA POR TRÁS DA CURVA"
	title.theme_type_variation = &"InkLabel"
	title.add_theme_font_override("font", UiTheme.title_font())
	title.add_theme_font_size_override("font_size", UiTokens.FONT_LG)
	col.add_child(title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_color_override("default_color", UiTokens.INK)
	_body.add_theme_font_override("normal_font", UiTheme.body_font(UiTokens.WEIGHT_BODY))
	_body.add_theme_font_override("bold_font", UiTheme.body_font(UiTokens.WEIGHT_BOLD))
	_body.add_theme_font_size_override("normal_font_size", UiTokens.FONT_SM)
	_body.add_theme_font_size_override("bold_font_size", UiTokens.FONT_SM)
	col.add_child(_body)


## Altura da linha y = h da fase (NAN = sem linha): a gaveta mostra o delta de
## ax² + bx + c = h, que diz quantas vezes a bala passa por aquela altura.
func set_height_line(h: float) -> void:
	_height_line = h


func set_accent(color: Color) -> void:
	_calc_on_paper = color.darkened(UiTokens.ON_PAPER_DARKEN)


func toggle() -> void:
	visible = not visible


func set_shot(s: Dictionary) -> void:
	if _body == null or not visible:
		return
	var calc := "#" + _calc_on_paper.to_html(false)
	var edit := "#" + UiTokens.EDITABLE_ON_PAPER.to_html(false)
	var v := Ballistics.vertex(s)
	var d := Ballistics.delta(s)
	var r := Ballistics.root(s)
	var moved: bool = absf(s.x_tank) > 0.01

	var lines := PackedStringArray()
	lines.append(
		(
			(
				"[b]a[/b] = −g / (2·v²·cos²θ) = [color=%s][b]%s[/b][/color]      "
				% [calc, Ballistics.fmt(s.a, 4)]
			)
			+ "[b]b[/b] = tg θ = [color=%s][b]%s[/b][/color]      " % [calc, Ballistics.fmt(s.t, 2)]
			+ (
				"[b]c[/b] = altura do canhão = [color=%s][b]%s m[/b][/color]"
				% [calc, Ballistics.fmt(s.h_cannon, 1)]
			)
		)
	)
	if moved:
		lines.append(
			(
				(
					"O tanque andou até x = [color=%s][b]%s m[/b][/color]: "
					% [edit, Ballistics.fmt(s.x_tank, 1)]
				)
				+ "a curva escorrega e b, c mudam; o [b]a[/b] não muda nunca."
			)
		)
	lines.append(
		(
			(
				"[b]Vértice[/b]   x = −b / 2a = [color=%s][b]%s m[/b][/color]"
				% [calc, Ballistics.fmt(v.x, 1)]
			)
			+ (
				"     altura = −delta / 4a = [color=%s][b]%s m[/b][/color]"
				% [calc, Ballistics.fmt(v.y, 1)]
			)
		)
	)
	lines.append(
		(
			(
				"[b]Raiz (Bhaskara)[/b]   delta = b² − 4ac = [color=%s][b]%s[/b][/color]"
				% [calc, Ballistics.fmt(d, 2)]
			)
			+ (
				"     x = (−b − √delta) / 2a = [color=%s][b]%s[/b][/color]"
				% [calc, "não toca o chão" if is_nan(r) else Ballistics.fmt(r, 1) + " m"]
			)
		)
	)
	if not is_nan(_height_line):
		var dh := Ballistics.delta_at(s, _height_line)
		var n := Ballistics.crossings(s, _height_line).size()
		var hs := Ballistics.fmt(_height_line, 0)
		var line := "[b]Linha y = %s[/b]   delta = b² − 4a(c − %s) = " % [hs, hs]
		line += "[color=%s][b]%s[/b][/color]" % [calc, Ballistics.fmt(dh, 2)]
		line += "   →  %d solução(ões) à frente" % n
		lines.append(line)
	var small := "[font_size=%d]" % UiTokens.FONT_XS
	lines.append(small + "Na física: altura máx. = c + v²·sen²θ / 2g   ·   ")
	lines[-1] += "saindo do chão, alcance = v²·sen(2θ) / g[/font_size]"
	_body.text = "\n".join(lines)
