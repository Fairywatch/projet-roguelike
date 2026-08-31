extends Area2D

var direction := Vector2.RIGHT
var speed := 220.0
var lifetime := 2.0
var source: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body == source:
		return
	if body.has_method("take_damage"):
		body.take_damage()
	queue_free()
