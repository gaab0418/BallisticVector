extends Node
## Gerenciador global de áudio — persistente entre cenas.
## Autoload registrado em project.godot como "AudioManager".

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var current_bgm_path: String = ""

var master_volume: float = 1.0
var bgm_volume: float = 0.5 # default
var sfx_volume: float = 1.0

func update_volumes() -> void:
	if bgm_player: bgm_player.volume_db = linear_to_db(bgm_volume * master_volume) - 8.0
	if sfx_player: sfx_player.volume_db = linear_to_db(sfx_volume * master_volume) - 3.0


func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	add_child(bgm_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)
	
	update_volumes()


func play_bgm(path: String) -> void:
	if current_bgm_path == path and bgm_player.playing:
		return
	current_bgm_path = path
	var stream = load(path)
	if stream:
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
			stream.loop = true
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
