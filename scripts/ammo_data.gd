class_name AmmoData
extends Resource

@export var ammo_name: String = "Sem nome"
@export var impulse: float = 500.0
@export var gravity: float = 400.0
@export var precision: float = 0.3      # 1.0 = perfeita, 0.0 = ruim, negativo = muito difícil
@export var damage: int = 10
@export var max_ammo: int = 10
@export var price: int = 10
@export var color: Color = Color(1.0, 0.85, 0.2, 1.0)  # Cor do projétil
