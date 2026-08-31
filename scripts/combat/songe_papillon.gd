extends "res://scripts/combat/base_mob.gd"

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var flutter_time := 0.0

func _on_ready() -> void:
	chase_speed = 130.0
	attack_range = 40.0
	telegraph_duration = 0.3
	attack_duration = 0.15
	cooldown_duration = 0.45
	hp = 1
	attack_shape.disabled = true
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

func _chase_velocity(to_player: Vector2) -> Vector2:
	flutter_time += 0.06
	var base_dir := to_player.normalized()
	var perpendicular := Vector2(-base_dir.y, base_dir.x)
	var wobble := perpendicular * sin(flutter_time * 6.0) * 0.6
	return (base_dir + wobble).normalized() * chase_speed

func _on_attack_begin() -> void:
	attack_shape.disabled = false

func _on_attack_end() -> void:
	attack_shape.disabled = true

func _on_death() -> void:
	attack_shape.disabled = true

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()
