extends "res://scripts/combat/base_mob.gd"

const ProjectileScene := preload("res://scenes/combat/Projectile.tscn")
const PROJECTILE_SPEED := 260.0

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

func _on_ready() -> void:
	chase_speed = 90.0
	attack_range = 150.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 0.7
	hp = 6
	attack_shape.disabled = true
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

func _on_attack_begin() -> void:
	if randf() < 0.5:
		attack_shape.disabled = false
	else:
		_fire_projectile()

func _on_attack_end() -> void:
	attack_shape.disabled = true

func _on_death() -> void:
	attack_shape.disabled = true

func _fire_projectile() -> void:
	if player == null:
		return
	var direction := (player.global_position - global_position).normalized()
	var projectile: Area2D = ProjectileScene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 34.0
	projectile.direction = direction
	projectile.speed = PROJECTILE_SPEED
	projectile.source = self

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()
