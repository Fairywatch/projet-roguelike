extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(0.4, false).timeout.connect(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_hit"):
		body.take_hit()
