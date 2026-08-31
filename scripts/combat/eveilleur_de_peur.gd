extends "res://scripts/combat/base_mob.gd"

const SongePapillonScene := preload("res://scenes/combat/SongePapillon.tscn")

func _on_ready() -> void:
	chase_speed = 35.0
	attack_range = 200.0
	telegraph_duration = 0.8
	attack_duration = 0.2
	cooldown_duration = 1.6
	hp = 4

func _on_attack_begin() -> void:
	for i in 2:
		var add: CharacterBody2D = SongePapillonScene.instantiate()
		get_tree().current_scene.add_child(add)
		var offset := Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		add.global_position = global_position + offset
