extends Area2D

@onready var visual: Polygon2D = $Visual

var arm_delay := 0.9

func _ready() -> void:
	visual.color = Color(0.85, 0.2, 0.2, 0.28)
	await get_tree().create_timer(arm_delay).timeout
	_detonate()

func _detonate() -> void:
	visual.color = Color(0.9, 0.15, 0.15, 0.6)
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage()
	await get_tree().create_timer(0.15).timeout
	queue_free()
