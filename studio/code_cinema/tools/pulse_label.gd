extends Label3D

@export var base_color := Color("#fff0f0")
@export var pulse_color := Color("#ff3333")
@export var speed := 4.0

var _clock := 0.0


func _process(delta: float) -> void:
	_clock += delta
	var wave := 0.5 + 0.5 * sin(_clock * speed * TAU)
	modulate = base_color.lerp(pulse_color, wave)
