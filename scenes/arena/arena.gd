extends Node2D

func _ready() -> void:
	# Inicializa a semente aleatória
	randomize()
	
	# Muda a cor do fundo para uma cor aleatória
	var bg = $BackgroundColorRect
	if bg:
		# Gera cores com um pouco mais de saturação/brilho
		bg.color = Color(randf_range(0.2, 0.8), randf_range(0.2, 0.8), randf_range(0.2, 0.8), 1.0)
