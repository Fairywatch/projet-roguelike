extends CharacterBody2D

const SPEED := 220.0
const ACCELERATION := 2800.0  # memes sensations qu'en combat (player_combat.gd)
const FRICTION := 2200.0

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

func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input_vector := Controls.move_vector()
	if abs(input_vector.x) > 0.1:
		sprite.flip_h = input_vector.x < 0
	var target := input_vector * SPEED
	velocity = velocity.move_toward(target, (ACCELERATION if target != Vector2.ZERO else FRICTION) * delta)
	move_and_slide()
