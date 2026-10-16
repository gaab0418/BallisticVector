class_name UiTokens
extends RefCounted
## Fonte unica de verdade do estilo visual do jogo.
##
## Toda constante daqui alimenta o Theme global (ui_theme.gd), um dos
## componentes de scripts/ui/ ou a arte procedural da arena e do mapa.
##
## Regra: nenhum literal de cor, de fonte ou de corpo de fonte fora deste arquivo.
##
## A paleta foi tirada dos assets que ja existiam: o ceu crepuscular e as
## montanhas do camp.jpg, o verde do tanque, a pedra do castelo e o papel do mapa
## nautico. Contraste conferido contra NIGHT_900 (fundo dos paineis): texto
## principal 14:1, destaques acima de 9:1, perigo 5,8:1 -- todos WCAG AA.

# ═════════════════════════════════════════════════════════════════════
#  PALETA BASE -- so nomes de material; as telas usam os papeis semanticos
# ═════════════════════════════════════════════════════════════════════

# ── Noite (fundos de painel, contornos) ──────────────────────────────
const NIGHT_950 := Color("120f19")
const NIGHT_900 := Color("1a1624")
const NIGHT_800 := Color("241f33")
const NIGHT_700 := Color("2f2942")
const NIGHT_600 := Color("3d3554")

# ── Crepusculo (ceu da arena) ────────────────────────────────────────
const SKY_TOP := Color("2a2440")
const SKY_MID := Color("4b4266")
const SKY_ROSE := Color("b8646e")
const SKY_GLOW := Color("e38b4c")

# ── Montanhas ao longe, da mais distante para a mais proxima ────────
const MOUNTAIN_FAR := Color("6a5d73")
const MOUNTAIN_MID := Color("4f4560")
const MOUNTAIN_NEAR := Color("3a3248")

# ── Terra e rocha (chao e obstaculos) ────────────────────────────────
const EARTH_LIGHT := Color("7a5a3e")
const EARTH := Color("5a4030")
const EARTH_DARK := Color("3b2a1e")
const ROCK_LIGHT := Color("8a7a70")
const ROCK := Color("5f5250")
const ROCK_DARK := Color("3d3438")

# ── Verde militar ────────────────────────────────────────────────────
const OLIVE_LIGHT := Color("7a8450")
const OLIVE := Color("4e5a36")
const OLIVE_DARK := Color("333c24")

# ── Latao (molduras, rebites, engrenagens) ───────────────────────────
const BRASS_LIGHT := Color("f0d28a")
const BRASS := Color("c89b4a")
const BRASS_DARK := Color("7e5f2c")

# ── Papel envelhecido e tinta (mapa, diagrama da ajuda) ──────────────
const PAPER := Color("e9dcb5")
const PAPER_DARK := Color("cdbb8a")
const INK := Color("2b2219")

# ═════════════════════════════════════════════════════════════════════
#  PAPEIS SEMANTICOS
# ═════════════════════════════════════════════════════════════════════

# ── Os tres destaques do jogo ────────────────────────────────────────
# Cada um tem um significado so, e a tela inteira respeita isso:
#   EDITABLE   -- o que o jogador pode mudar (engrenagens, foco, acao principal)
#   CALCULATED -- o que o jogo calculou (alcance, altura, vertice, raiz)
#   DANGER     -- dano, perigo, acao destrutiva
# Nenhum deles aparece sozinho: sempre vem com icone, forma ou texto.
const EDITABLE := Color("ffc844")
const CALCULATED := Color("62d6e8")
## Carmim, e nao laranja: a mira da Terra e vermelho-alaranjada, e perigo
## precisa continuar sendo outra cor.
const DANGER := Color("ff3f62")
const SUCCESS := Color("86d46b")
## Moeda do jogo. Mais quente que EDITABLE para nao ser lida como "editavel".
const GOLD := Color("f2b33d")

# Os mesmos papeis sobre PAPER, escurecidos para manter 4,5:1.
const EDITABLE_ON_PAPER := Color("774b00")
const CALCULATED_ON_PAPER := Color("145763")
const DANGER_ON_PAPER := Color("9a2016")

## Nome antigo de EDITABLE, mantido porque e o acento de interacao do jogo.
const AMBER := EDITABLE

# ── Texto ────────────────────────────────────────────────────────────
const TEXT := Color("efe6cf")
const TEXT_HOVER := Color("fffaea")
const TEXT_DIM := Color("cfc3a6")
const TEXT_MUTED := Color("a99c80")
const TEXT_DISABLED := Color("77705f")
## Titulos: latao claro, para nao competir com o ambar do que e editavel.
const TITLE := BRASS_LIGHT
## Contorno de texto escrito direto sobre arte (mapa, mundo da arena).
const TEXT_OUTLINE := NIGHT_950
const AMBER_OUTLINE := NIGHT_950

# ── Superficies ──────────────────────────────────────────────────────
const BG_PANEL := Color(0.102, 0.086, 0.141, 0.9)
const BG_MODAL := NIGHT_900
const BG_CARD := NIGHT_800
const BG_HUD := Color(0.102, 0.086, 0.141, 0.88)
const BG_SELECTED := Color("4a3a1c")
const BACKDROP := Color(0.07, 0.06, 0.1, 0.72)
const SHADOW := Color(0.04, 0.03, 0.06, 0.6)
const TRANSPARENT := Color(0, 0, 0, 0)

# ── Botoes ───────────────────────────────────────────────────────────
const BG_BUTTON := NIGHT_700
const BG_BUTTON_HOVER := NIGHT_600
const BG_BUTTON_PRESSED := NIGHT_800
const BG_BUTTON_DISABLED := Color(0.14, 0.125, 0.18, 0.7)
## Botao principal: latao escuro, para a acao em destaque saltar da tela.
const BG_PRIMARY := Color("5a4520")
const BG_PRIMARY_HOVER := Color("75592a")
const BG_DANGER := Color("5c1f1c")
const BG_DANGER_HOVER := Color("7a2a25")

# ── Molduras ─────────────────────────────────────────────────────────
const BORDER := BRASS_DARK
const BORDER_HOVER := BRASS
const BORDER_PRESSED := Color("5e4621")
const BORDER_DISABLED := Color("4a4038")
const BORDER_MODAL := BRASS
const BEVEL_LIGHT := Color(1, 0.95, 0.8, 0.22)
const BEVEL_DARK := Color(0, 0, 0, 0.35)

# ── HUD ──────────────────────────────────────────────────────────────
const ARMOR_FILL := Color("7fc15a")
const ARMOR_LOW := DANGER
const ARMOR_BG := NIGHT_950
const GEAR_IDLE := Color("8c7a5c")

# ── Mundo ────────────────────────────────────────────────────────────
## Multiplicador do flash branco de dano (acima de 1 estoura para branco).
const HIT_FLASH := Color(3.0, 3.0, 3.0, 1.0)
const NO_TINT := Color(1, 1, 1, 1)
const ENEMY_SHOT := Color("ff6a2a")

# ═════════════════════════════════════════════════════════════════════
#  TIPOGRAFIA
# ═════════════════════════════════════════════════════════════════════

# Tres arquivos, todos OFL (licencas em assets/fonts/):
#   VT323     -- texto, numeros e formulas. Fonte de terminal em pixel, com
#                digitos inequivocos (5 nao vira S, 8 nao vira B) e "i" com pingo
#                separado de verdade, em qualquer corpo.
#   Handjet   -- so fallback, para os glifos que a VT323 nao tem (θ e setas).
#                Ja foi a fonte de texto, mas o pingo do "i" fica a ~1 px da haste
#                e some na tela: "Meia" virava "Mela", "Tiro" virava "Tlro".
#   Jersey 10 -- titulos e logotipo. NAO tem ² nem ±: so para palavras.
# (O Pixelify Sans foi o primeiro testado e caiu porque o 5 parecia S.)
const FONT_BODY_PATH := "res://assets/fonts/VT323-Regular.ttf"
const FONT_FALLBACK_PATH := "res://assets/fonts/Handjet-Variable.ttf"
const FONT_TITLE_PATH := "res://assets/fonts/Jersey10-Regular.ttf"
## A VT323 tem um peso so; o "negrito" e um engrossamento sintetico leve, que
## nao chega a fechar o pingo do i.
const WEIGHT_BODY := 0
const WEIGHT_BOLD := 1
const EMBOLDEN := 0.35

# ── Escala tipografica ───────────────────────────────────────────────
# A VT323 tem desenho pequeno dentro do corpo: 20 nela le como um 16 comum. O
# piso de leitura confortavel a 1280x720 fica em FONT_SM; FONT_XS e so para
# rotulos curtos, nunca para frases.
const FONT_XS := 20
const FONT_SM := 22
const FONT_MD := 24
const FONT_LG := 28
const FONT_XL := 34
# Os degraus de titulo seguem a grade do Jersey 10 (1 pixel da fonte = corpo
# x 75/1400): 38 e 56 caem perto de 2 e 3 pixels de tela por pixel da fonte.
const FONT_TITLE := 38
const FONT_DISPLAY := 56
const FONT_HERO := 76

# ═════════════════════════════════════════════════════════════════════
#  GEOMETRIA
# ═════════════════════════════════════════════════════════════════════

## Tamanho do "pixel" das molduras procedurais, em pixels de tela. Casa com o
## traco de ~2 px das fontes, para moldura e letra parecerem da mesma arte.
const PX := 2
const RADIUS := 0
const RADIUS_LG := 0
const BORDER_W := 2 * PX
const BORDER_W_THIN := PX
const SHADOW_SIZE := 2 * PX
const OUTLINE_SIZE := 3 * PX
const TEXT_OUTLINE_SIZE := 4

# ── Espacamento ──────────────────────────────────────────────────────
const GAP_SM := 6
const GAP := 12
const GAP_LG := 18
const PAD_SM := 8
const PAD := 16
const PAD_LG := 24

# ── Respiro interno do botao ─────────────────────────────────────────
const BTN_PAD_H := 16
const BTN_PAD_V := 8
## Espaco entre o icone e o rotulo.
const BTN_ICON_GAP := 10
const BTN_ICON_MAX := 24
const BTN_ICON_ONLY_MAX := 26

# ── Alvos de toque ───────────────────────────────────────────────────
const BTN_MIN := Vector2(280, 52)
const BTN_ICON := Vector2(48, 48)

# ── Animacao ─────────────────────────────────────────────────────────
const ANIM_FAST := 0.12
const ANIM := 0.25
const FLASH_TIME := 0.35

# ═════════════════════════════════════════════════════════════════════
#  TINTS DE SPRITE (modulate)
# ═════════════════════════════════════════════════════════════════════

# Valores acima de 1 clareiam o sprite em vez de so tingi-lo: e o que faz uma
# base realcar sobre o tom do papel do mapa.
const BASE_HOVER := Color(1.7, 1.45, 0.55, 1.0)
const BASE_HOVER_DONE := Color(1.0, 0.82, 0.4, 0.95)
const BASE_DONE := Color(0.6, 0.6, 0.6, 0.85)
const MENU_PLANE_TINT := Color(0.2, 0.2, 0.2, 0.7)

# ═════════════════════════════════════════════════════════════════════
#  TEMAS DO MUNDO DA ARENA -- um por planeta
# ═════════════════════════════════════════════════════════════════════

# Ceu de cima para baixo (top, mid, horizon, glow), duas camadas de montanha ao
# longe, chao (lip = a faixa de cima, grama ou poeira), rocha dos obstaculos.
# A Terra repete o crepusculo do camp.jpg, para menu e arena serem o mesmo lugar.
const WORLD_EARTH := {
	"sky": [Color("231d38"), Color("4b4266"), Color("b8646e"), Color("e38b4c")],
	"stars": 0.25,
	"far": Color("6a5d73"),
	"mid": Color("4f4560"),
	"lip": Color("6b7a3e"),
	"lip_dark": Color("4e5a36"),
	"ground": Color("5a4030"),
	"ground_dark": Color("3b2a1e"),
	"speck": Color("7a5a3e"),
	"rock": [Color("8a7a70"), Color("5f5250"), Color("3d3438")],
	"disc": Color("f2b36a"),
	# Cor do que e calculado (curva, vertice, raiz, resultados do painel) neste
	# mundo: vermelho-alaranjado sobre o ceu roxo do crepusculo.
	"aim": Color("ff7a3d"),
}
const WORLD_MOON := {
	"sky": [Color("05050b"), Color("0e1020"), Color("1d2136"), Color("2e3450")],
	"stars": 1.0,
	"far": Color("5a5d6e"),
	"mid": Color("41444f"),
	"lip": Color("b4b4bc"),
	"lip_dark": Color("8a8a94"),
	"ground": Color("6e6e78"),
	"ground_dark": Color("4a4a54"),
	"speck": Color("8e8e98"),
	"rock": [Color("a4a4ae"), Color("7a7a86"), Color("4e4e58")],
	# A Terra vista da Lua.
	"disc": Color("5d9ad6"),
	"aim": Color("62d6e8"),
}
const WORLD_MARS := {
	"sky": [Color("2e1a26"), Color("6e3a30"), Color("c0784c"), Color("e8a868")],
	"stars": 0.1,
	"far": Color("8a5040"),
	"mid": Color("6a3a2e"),
	"lip": Color("c87a48"),
	"lip_dark": Color("9a5636"),
	"ground": Color("8a4426"),
	"ground_dark": Color("5a2c1a"),
	"speck": Color("a85e38"),
	"rock": [Color("b07050"), Color("8a5038"), Color("5a3020")],
	"disc": Color("f0d8b0"),
	# Ceu alaranjado: a mira vira azul para contrastar.
	"aim": Color("7cc8ff"),
}
const WORLD_JUPITER := {
	"sky": [Color("2a1a14"), Color("6a3a20"), Color("b8703a"), Color("eab070")],
	"stars": 0.0,
	"far": Color("7a5038"),
	"mid": Color("5a3a28"),
	"lip": Color("b08050"),
	"lip_dark": Color("80583a"),
	"ground": Color("70482a"),
	"ground_dark": Color("4a2e1c"),
	"speck": Color("8a6040"),
	"rock": [Color("a07a58"), Color("7a5a40"), Color("4e3626")],
	"disc": Color("f6d6a0"),
	"aim": Color("7cc8ff"),
}

# ── Elementos da arena ───────────────────────────────────────────────
## Fita metrica da regua: papel envelhecido com tinta, como o mapa.
const RULER_TAPE := Color("e9dcb5")
const RULER_INK := Color("2b2219")
## Contorno escuro da linha de mira. A cor da linha vem de "aim" do mundo.
const AIM_OUTLINE := Color(0.05, 0.04, 0.08, 0.75)
## Opacidade do trecho "fantasma" (depois da batida) e da faixa de queda.
const AIM_GHOST_ALPHA := 0.4
const BAND_ALPHA := 0.28
## Quanto escurecer a cor do mundo para escrever sobre papel (4,5:1 ou mais).
const ON_PAPER_DARKEN := 0.55
const CLOUD := Color(1, 0.92, 0.85, 0.16)
const STAR_LIGHT := Color(1, 0.97, 0.9)
const SMOKE := Color(0.85, 0.8, 0.75, 0.8)
const FIRE := Color("ffb347")
const FIRE_HOT := Color("fff1b0")
const DUST := Color(0.75, 0.62, 0.48, 0.85)
const MOVE_ZONE := Color(1, 0.784, 0.267, 0.18)

# ── Mapa de guerra ───────────────────────────────────────────────────
const MEDAL_BRONZE := Color("d08a4c")
const MEDAL_SILVER := Color("d6dce4")
const MEDAL_GOLD := Color("ffd24a")
## Base bloqueada: castelo apagado no papel.
const MAP_LOCKED := Color(0.45, 0.42, 0.4, 0.55)
## Tinta da rota da campanha desenhada no mapa.
const MAP_ROUTE := Color(0.17, 0.13, 0.1, 0.7)
const MAP_ROUTE_DONE := Color(0.6, 0.12, 0.08, 0.85)

# ── Telas de fim de jogo ─────────────────────────────────────────────
const END_VICTORY_SHADE := Color(0.07, 0.06, 0.1, 0.55)
const END_DEFEAT_SHADE := Color(0.18, 0.04, 0.04, 0.7)

# ── Brilho e sombra internos dos icones e discos ─────────────────────
const SHINE := Color(1, 1, 1, 0.35)
const SHADE := Color(0, 0, 0, 0.25)

# ── Mesa do mapa (pergaminho cartesiano) ─────────────────────────────
const WOOD := Color("4a3324")
const WOOD_DARK := Color("2e2018")
## Terra das ilhas: papel mais claro que o mar.
const MAP_LAND := Color("f4eacb")
const MAP_TREE := Color("9fae74")
## Mar do pergaminho: aguada esverdeada sobre o papel, para a terra saltar.
const MAP_SEA := Color(0.55, 0.66, 0.6, 0.28)

# ── Alvos e inimigos novos ───────────────────────────────────────────
const BALLOON_A := Color("e8584a")
const BALLOON_B := Color("f2b33d")
const BALLOON_C := Color("6fb2e0")
## Tanque inimigo: o mesmo sprite do jogador, tingido de ferrugem.
const ENEMY_TANK_TINT := Color(1.0, 0.62, 0.5)

# ── Mundo Invertido (bonus, a > 0) ───────────────────────────────────
const WORLD_INVERTED := {
	"sky": [Color("0f1a24"), Color("1f3a44"), Color("3f6e66"), Color("8fd0a0")],
	"stars": 0.8,
	"far": Color("2e4a4e"),
	"mid": Color("223a3e"),
	"lip": Color("7ac0a0"),
	"lip_dark": Color("4e8a74"),
	"ground": Color("3a4a44"),
	"ground_dark": Color("26322e"),
	"speck": Color("5a7068"),
	"rock": [Color("7a9a90"), Color("4e6a62"), Color("2e403a")],
	"disc": Color("d0f0e0"),
	# Ceu verde-azulado de aurora: a mira vira magenta para contrastar.
	"aim": Color("ff7ad0"),
}
