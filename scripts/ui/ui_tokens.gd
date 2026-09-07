class_name UiTokens
extends RefCounted
## Fonte unica de verdade do estilo visual do jogo.
##
## Antes disto, a cor de marca #FFD94D estava escrita a mao em cinco arquivos e a
## escala tipografica tinha catorze tamanhos sem sistema. Toda constante daqui
## alimenta o Theme global (ui_theme.gd) ou um dos componentes de scripts/ui/.
##
## Regra: nenhum literal de cor ou de corpo de fonte fora deste arquivo.

# ── Marca ────────────────────────────────────────────────────────────
const AMBER := Color(1.0, 0.85, 0.3)
const AMBER_OUTLINE := Color(0.1, 0.08, 0.05)
const GOLD := Color(0.85, 0.7, 0.25)

# ── Superficies ──────────────────────────────────────────────────────
const BG_PANEL := Color(0.05, 0.04, 0.03, 0.65)
const BG_MODAL := Color(0.15, 0.12, 0.1, 0.98)
const BG_CARD := Color(0.12, 0.1, 0.07, 0.85)
const BG_HUD := Color(0.08, 0.06, 0.04, 0.82)
const BACKDROP := Color(0, 0, 0, 0.6)
const SHADOW := Color(0, 0, 0, 0.5)

# ── Botoes ───────────────────────────────────────────────────────────
const BG_BUTTON := Color(0.22, 0.18, 0.13, 0.95)
const BG_BUTTON_HOVER := Color(0.35, 0.28, 0.18, 1.0)
const BG_BUTTON_PRESSED := Color(0.15, 0.12, 0.08, 1.0)
const BG_BUTTON_DISABLED := Color(0.14, 0.12, 0.1, 0.6)

# ── Bordas ───────────────────────────────────────────────────────────
const BORDER := Color(0.55, 0.42, 0.22, 1.0)
const BORDER_HOVER := Color(0.85, 0.68, 0.35, 1.0)
const BORDER_PRESSED := Color(0.4, 0.3, 0.15, 1.0)
const BORDER_DISABLED := Color(0.3, 0.26, 0.18, 0.7)
const BORDER_MODAL := Color(0.6, 0.45, 0.25, 1.0)

# ── Texto ────────────────────────────────────────────────────────────
const TEXT := Color(0.9, 0.85, 0.75)
const TEXT_HOVER := Color(1.0, 0.98, 0.9)
const TEXT_DIM := Color(0.8, 0.75, 0.65)
const TEXT_MUTED := Color(0.7, 0.6, 0.42)
const TEXT_DISABLED := Color(0.5, 0.46, 0.4)

# ── Semantica ────────────────────────────────────────────────────────
const DANGER := Color(1.0, 0.2, 0.2)
const SUCCESS := Color(0.4, 0.8, 0.35)
const ARMOR_FILL := Color(0.2, 0.6, 0.8)
const ARMOR_BG := Color(0.1, 0.1, 0.1, 0.8)

# ── Escala tipografica ───────────────────────────────────────────────
# Ancorada no default 16 do Godot. Seis degraus no lugar dos catorze
# tamanhos avulsos que existiam antes.
const FONT_XS := 12
const FONT_SM := 14
const FONT_MD := 16
const FONT_LG := 20
const FONT_XL := 26
const FONT_DISPLAY := 34

# ── Geometria ────────────────────────────────────────────────────────
const RADIUS := 6
const RADIUS_LG := 12
const BORDER_W := 3
const BORDER_W_THIN := 2
const SHADOW_SIZE := 6
const OUTLINE_SIZE := 8

# ── Espacamento ──────────────────────────────────────────────────────
const GAP := 12
const GAP_LG := 18
const PAD_SM := 8
const PAD := 16
const PAD_LG := 24

# ── Respiro interno do botao ─────────────────────────────────────────
# Sem content_margin o StyleBoxFlat encosta o conteudo na borda, e com
# icon_alignment LEFT o icone cola no canto.
const BTN_PAD_H := 14
const BTN_PAD_V := 8
## Espaco entre o icone e o rotulo.
const BTN_ICON_GAP := 10

# ── Alvos de toque ───────────────────────────────────────────────────
const BTN_MIN := Vector2(280, 50)
const BTN_ICON := Vector2(44, 44)
