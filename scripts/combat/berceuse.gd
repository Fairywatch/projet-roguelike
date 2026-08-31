extends "res://scripts/combat/base_mob.gd"

const ProjectileScene := preload("res://scenes/combat/Projectile.tscn")
const PROJECTILE_SPEED := 220.0

func _on_ready() -> void:
	chase_speed = 45.0
	attack_range = 220.0
	telegraph_duration = 0.7
	attack_duration = 0.15
	cooldown_duration = 1.1

func _on_attack_begin() -> void:
	if player == null:
		return
	var direction := (player.global_position - global_position).normalized()
	var projectile: Area2D = ProjectileScene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 26.0
	projectile.direction = direction
	projectile.speed = PROJECTILE_SPEED
	projectile.source = self
