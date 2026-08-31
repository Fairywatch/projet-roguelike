extends "res://scripts/combat/base_mob.gd"

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

func _on_ready() -> void:
	attack_shape.disabled = true
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

func _on_attack_begin() -> void:
	attack_shape.disabled = false

func _on_attack_end() -> void:
	attack_shape.disabled = true

func _on_death() -> void:
	attack_shape.disabled = true

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()
