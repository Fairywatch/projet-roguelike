extends Area2D

func register_hit(damage: int = 1) -> void:
	var target := get_parent()
	if target.has_method("take_hit"):
		target.take_hit(damage)
