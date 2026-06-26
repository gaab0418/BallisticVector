extends Node
## Gerenciador global de áudio — persistente entre cenas.
## Autoload registrado em project.godot como "AudioManager".

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var current_bgm_path: String = ""


func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -8.0
	add_child(bgm_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	sfx_player.volume_db = -3.0
	add_child(sfx_player)


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
