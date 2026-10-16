class_name Cosmetics
extends RefCounted
## Catalogo da Oficina da Ada: camuflagens, rastros de bala e bandeirinhas,
## pagos em latao (100 por fase vencida). O primeiro item de cada tipo e o
## padrao, gratis e ja equipado.

const CAMO_SHADER := preload("res://assets/shaders/camo.gdshader")

const SLOTS := ["camo", "trail", "flag"]
const SLOT_NAMES := {"camo": "Camuflagem", "trail": "Rastro", "flag": "Bandeira"}

## camo: tres cores (sombra, meio, luz) ou [] para o sprite original.
const CAMOS := [
	{"id": "camo_original", "name": "Original", "price": 0, "colors": []},
	{"id": "camo_desert", "name": "Deserto", "price": 150, "colors": ["6a5232", "b08a52", "e0c890"]},
	{"id": "camo_snow", "name": "Neve", "price": 150, "colors": ["5a6470", "a8b4be", "eef2f6"]},
	{"id": "camo_jungle", "name": "Selva", "price": 200, "colors": ["1f3a1c", "3e6a2e", "7aa04a"]},
	{"id": "camo_night", "name": "Noite", "price": 200, "colors": ["1e2438", "344068", "5a6aa0"]},
	{"id": "camo_mars", "name": "Marte", "price": 250, "colors": ["5a2016", "a8442a", "e08050"]},
	{"id": "camo_brass", "name": "Latão", "price": 300, "colors": ["6e4a1a", "c89b4a", "f2d690"]},
	{"id": "camo_parabola", "name": "Parábola", "price": 400, "colors": ["3a1a5a", "c040a0", "62d6e8"]},
]

## trail: estilo do desenho e a cor base.
const TRAILS := [
	{"id": "trail_smoke", "name": "Fumaça", "price": 0, "style": "line", "color": "d8ccc0"},
	{"id": "trail_ink", "name": "Tinta", "price": 120, "style": "dots", "color": "2b2219"},
	{"id": "trail_fire", "name": "Fogo", "price": 150, "style": "fire", "color": "ff8a3d"},
	{"id": "trail_ice", "name": "Gelo", "price": 150, "style": "line", "color": "8fe8ff"},
	{"id": "trail_stars", "name": "Estrelinhas", "price": 200, "style": "stars", "color": "ffd24a"},
	{"id": "trail_rainbow", "name": "Arco-íris", "price": 300, "style": "rainbow", "color": "ffffff"},
]

## flag: icone de UiIcon desenhado no flamula, e a cor do pano.
const FLAGS := [
	{"id": "flag_none", "name": "Nenhuma", "price": 0, "icon": "", "color": "000000"},
	{"id": "flag_star", "name": "Estrela", "price": 100, "icon": "star", "color": "c0392b"},
	{"id": "flag_heart", "name": "Coração", "price": 100, "icon": "shield", "color": "e86fa0"},
	{"id": "flag_gear", "name": "Engrenagem", "price": 150, "icon": "gear", "color": "4e5a36"},
	{"id": "flag_vertex", "name": "Vértice", "price": 150, "icon": "vertex", "color": "1f6e7a"},
	{"id": "flag_parabola", "name": "Parábola", "price": 250, "icon": "parabola", "color": "3a1a5a"},
]


static func items(slot: String) -> Array:
	match slot:
		"camo":
			return CAMOS
		"trail":
			return TRAILS
	return FLAGS


static func item(item_id: String) -> Dictionary:
	for slot in SLOTS:
		for it in items(slot):
			if it.id == item_id:
				return it
	return {}


static func equipped(slot: String) -> Dictionary:
	var it := item(Global.equipped.get(slot, ""))
	return it if not it.is_empty() else items(slot)[0]


## Material de camuflagem para os sprites do tanque; null = sprite original.
static func camo_material(camo: Dictionary) -> ShaderMaterial:
	var colors: Array = camo.get("colors", [])
	if colors.is_empty():
		return null
	var mat := ShaderMaterial.new()
	mat.shader = CAMO_SHADER
	mat.set_shader_parameter("c_dark", Color(colors[0]))
	mat.set_shader_parameter("c_mid", Color(colors[1]))
	mat.set_shader_parameter("c_light", Color(colors[2]))
	return mat


## Aplica a camuflagem equipada em todos os sprites de um tanque.
static func dress_tank(sprites: Array) -> void:
	var mat := camo_material(equipped("camo"))
	for s in sprites:
		if s is CanvasItem:
			s.material = mat
