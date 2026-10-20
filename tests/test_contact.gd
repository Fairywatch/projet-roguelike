# Lancer : godot --headless --path . --script res://tests/test_contact.gd
# Un mob pose sur le joueur (atterrissage de saut, teleportation) ne doit pas le suivre.
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.new_run(0)
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	for m in get_nodes_in_group("mobs"):
		m.free()
	var arena = current_scene
	arena.combat_over = true
	var p = arena.player
	p.invincible = true
	for key in [KEY_A, KEY_D, KEY_S]:  # Q, D, S : on s'eloigne du mob (pose un peu au-dessus)
		p.global_position = Vector2(450, 300)
		p.move_velocity = Vector2.ZERO  # pas d'elan du tour precedent
		var mob: BaseMob = Bestiary.make("lundi/mouton")
		arena.add_child(mob)
		mob.global_position = p.global_position + Vector2(0, -10)
		mob.chase_speed = 0.0
		mob.attack_range = 0.0
		var start := mob.global_position
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.pressed = true
		Input.parse_input_event(ev)
		for i in 20:
			await physics_frame
		ev.pressed = false
		Input.parse_input_event(ev)
		assert(p.global_position.distance_to(Vector2(450, 300)) > 40.0)
		assert(mob.global_position.distance_to(start) < 20.0)  # juste le temps de se decoller, il ne suit pas
		mob.free()
	print("test_contact OK")
	quit()
