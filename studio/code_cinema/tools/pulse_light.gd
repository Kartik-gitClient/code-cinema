extends Light3D

@export var base_energy := 2.0
@export var speed := 2.0
@export var depth := 0.3

var _clock := 0.0


func _ready() -> void:
	base_energy = light_energy


func _process(delta: float) -> void:
	_clock += delta
	var wave := 0.5 + 0.5 * sin(_clock * speed * TAU)
	light_energy = base_energy * (1.0 - depth * wave)
