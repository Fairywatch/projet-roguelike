extends "res://scripts/combat/base_mob.gd"

const AoEZoneScene := preload("res://scenes/combat/AoEZone.tscn")

func _on_ready() -> void:
	chase_speed = 40.0
	attack_range = 260.0
	telegraph_duration = 0.9
	attack_duration = 0.2
	cooldown_duration = 1.3

func _on_telegraph_begin() -> void:
	if player == null:
		return
	var zone: Area2D = AoEZoneScene.instantiate()
	get_tree().current_scene.add_child(zone)
	zone.global_position = player.global_position
	zone.arm_delay = telegraph_duration
