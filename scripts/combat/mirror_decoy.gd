extends Node2D

var time := 0.0

func _process(delta: float) -> void:
	time += delta
	modulate.a = 1.0 - (time / 1.5)
	scale = Vector2.ONE * (1.0 + sin(time * 10.0) * 0.1)
	if time >= 1.5:
		queue_free()
