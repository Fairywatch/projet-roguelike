extends CharacterBody2D

const SPEED := 220.0

var frozen := false

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input_vector := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	velocity = input_vector * SPEED
	move_and_slide()
