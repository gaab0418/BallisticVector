class_name Narrator
extends RefCounted
## Le em voz alta as falas da Ada com a voz do sistema (text-to-speech), para
## criancas que ainda leem devagar. Liga em Ajustes > "Narrar as falas".
## Sem voz em portugues instalada, fica mudo (o botao avisa).


static func available() -> bool:
	return not _voice().is_empty()


static func speak(text: String) -> void:
	if not Global.narration:
		return
	var voice := _voice()
	if voice.is_empty():
		return
	DisplayServer.tts_stop()
	# Simbolos que a voz leria como nome ("estrela preta") saem antes.
	var clean := text.replace("★", "").replace("·", ",").replace("Δ", "delta")
	DisplayServer.tts_speak(clean, voice, 80, 1.0, 1.0)


static func stop() -> void:
	if Global.narration:
		DisplayServer.tts_stop()


static func _voice() -> String:
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return ""
	var voices := DisplayServer.tts_get_voices_for_language("pt")
	return voices[0] if voices.size() > 0 else ""
