extends Node
## Gerenciador global de audio -- persistente entre cenas.
## Autoload registrado em project.godot como "AudioManager".
##
## O volume mora so no bus (os sliders de AudioSettingsPanel leem e escrevem
## nele); um segundo estagio de volume multiplicaria com este.
##
## A trilha entra mais baixa que os efeitos, de proposito.

const START_MASTER := 0.5
const START_BGM_DB := -8.0
const START_SFX_DB := -3.0

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var current_bgm_path: String = ""


func _ready() -> void:
	# O audio nunca pausa junto com o jogo: a ajuda e o menu de pausa congelam a
	# arvore inteira, e sem isto a trilha cortaria e os cliques do proprio
	# overlay ficariam mudos.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_set_bus_db("Master", linear_to_db(START_MASTER))
	_set_bus_db("BGM", START_BGM_DB)
	_set_bus_db("SFX", START_SFX_DB)

	bgm_player = _make_player("BGM")
	bgm_player.finished.connect(_on_bgm_finished)
	sfx_player = _make_player("SFX")


func play_bgm(path: String) -> void:
	if current_bgm_path == path and bgm_player.playing:
		return
	current_bgm_path = path
	var stream = load(path)
	if stream:
		bgm_player.stream = stream
		bgm_player.play()


func stop_bgm() -> void:
	bgm_player.stop()
	current_bgm_path = ""


func play_sfx(path: String) -> void:
	var stream = load(path)
	if stream:
		sfx_player.stream = stream
		sfx_player.play()


## O bus so nao existe se alguem remover default_bus_layout.tres; nesse caso o
## som sai pelo Master em vez de a cena quebrar com indice -1.
func _make_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name if AudioServer.get_bus_index(bus_name) != -1 else "Master"
	add_child(player)
	return player


func _set_bus_db(bus_name: String, value_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		AudioServer.set_bus_volume_db(index, value_db)


func _on_bgm_finished() -> void:
	if current_bgm_path != "":
		bgm_player.play()
