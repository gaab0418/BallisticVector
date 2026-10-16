class_name Achievements
extends RefCounted
## Selos do Caderno da Ada: pequenas conquistas que premiam entender a conta,
## nao so vencer. Global guarda quais ja sairam (Global.achievements).

const LIST := [
	{"id": "first_hit", "name": "Primeiro acerto", "text": "Acerte um castelo pela primeira vez.", "icon": "target"},
	{"id": "sharpshooter", "name": "De primeira", "text": "Acerte o castelo com o primeiro tiro da fase.", "icon": "star"},
	{"id": "three_stars", "name": "Ilha de ouro", "text": "Três estrelas em todas as fases de uma base.", "icon": "star"},
	{"id": "chief", "name": "Caçador de chefes", "text": "Derrube um chefe.", "icon": "shield"},
	{"id": "chiefs_all", "name": "Lenda da parábola", "text": "Derrube os sete chefes.", "icon": "shield"},
	{"id": "intercept", "name": "Interceptador", "text": "Derrube um drone na rota.", "icon": "target"},
	{"id": "bounce", "name": "Rei do gelo", "text": "Acerte um alvo depois do quique.", "icon": "parabola"},
	{"id": "guesser", "name": "Chute certeiro", "text": "No modo chute, erre por menos de 1 m.", "icon": "root"},
	{"id": "lab", "name": "Cientista", "text": "Dê 10 tiros no Laboratório.", "icon": "vertex"},
	{"id": "workshop", "name": "Estilo próprio", "text": "Compre algo na Oficina da Ada.", "icon": "gear"},
	{"id": "reader", "name": "Leitor do caderno", "text": "Abra 10 páginas do caderno.", "icon": "parabola"},
	{"id": "duel_win", "name": "Venci a Ada", "text": "Vença a Ada no Duelo.", "icon": "star"},
]


static func item(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}
