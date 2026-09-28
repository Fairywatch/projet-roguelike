extends CharacterBody2D

const SPEED := 220.0

@onready var sprite: AnimatedSprite2D = $Sprite

var frozen := false
var bob_time := 0.0

func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = PlayerFrames.make()

func _process(delta: float) -> void:
	PlayerFrames.animate(sprite, velocity.length() > 10.0)
	if velocity.length() > 10.0:
		bob_time += delta
		sprite.position.y = round(-abs(sin(bob_time * 12.0)) * 2.0)
	else:
		sprite.position.y = 0.0

func _draw() -> void:
	Fx.draw_shadow(self, PlayerFrames.SHADOW_Y, 26.0)

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
	if abs(input_vector.x) > 0.1:
		sprite.flip_h = input_vector.x < 0
	velocity = input_vector * SPEED
	move_and_slide()
