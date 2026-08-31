extends "res://scripts/combat/base_mob.gd"

const CHARGE_SPEED := 320.0

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var charge_direction := Vector2.ZERO

func _on_ready() -> void:
	chase_speed = 50.0
	attack_range = 140.0
	telegraph_duration = 0.7
	attack_duration = 0.35
	cooldown_duration = 1.0
	hp = 4
	attack_shape.disabled = true
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

func _on_attack_begin() -> void:
	attack_shape.disabled = false
	charge_direction = Vector2.ZERO
	if player != null:
		charge_direction = (player.global_position - global_position).normalized()

func _on_attack_end() -> void:
	attack_shape.disabled = true
	charge_direction = Vector2.ZERO

func _on_death() -> void:
	attack_shape.disabled = true

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()

func _physics_process(delta: float) -> void:
	if state == State.ATTACK and charge_direction != Vector2.ZERO:
		velocity = charge_direction * CHARGE_SPEED
		move_and_slide()
		return
	super._physics_process(delta)
