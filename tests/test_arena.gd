# Lancer : godot --headless --path . --script res://tests/test_arena.gd
extends SceneTree

func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 3:
		await process_frame

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame  # laisse GameState._ready (chargement de la sauvegarde) passer avant la mise en place
	# Fichier a part : les tests ne touchent pas a la vraie sauvegarde du joueur.
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.new_run()
	gs.floor_index = 0
	gs.new_run()

	# Plusieurs ennemis, et le combat ne se termine pas tout seul.
	gs.take_item("mouchoir_usage")
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	var arena = current_scene
	var mobs := get_nodes_in_group("mobs")
	assert(mobs.size() >= 2 and mobs.size() <= arena.MAX_MOBS)
	assert(not arena.combat_over)
	# La musique de combat tourne (lecteur ajoute a la racine, en boucle).
	var music_players := root.get_children().filter(func(n): return n is AudioStreamPlayer and n.get_meta("track", "") == "combat")
	assert(music_players.size() == 1 and music_players[0].playing)
	assert(music_players[0].stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)

	# Mouchoir a PV pleins : pas de charge gaspillee. Blesse : soigne et consomme.
	await _press(KEY_E)
	assert(gs.active_charges == gs.ACTIVE_MAX_CHARGES)
	arena.player.hp -= 1
	await _press(KEY_E)
	assert(gs.active_charges == gs.ACTIVE_MAX_CHARGES - 1)
	assert(arena.player.hp == arena.player.max_hp)

	# Reveil strident : etourdit vraiment (le telegraphe en cours est annule).
	gs.take_item("reveil_strident")
	var mob = mobs[0]
	mob.global_position = arena.player.global_position + Vector2(60, 0)
	mob._start_telegraph()
	await _press(KEY_E)
	assert(mob.state == BaseMob.State.COOLDOWN)
	await create_timer(mob.telegraph_duration + 0.1).timeout
	assert(mob.state == BaseMob.State.COOLDOWN)

	# Victoire quand tous les ennemis sont morts, et l'objet actif se recharge.
	for m in get_nodes_in_group("mobs"):
		m.take_hit(999)
	for i in 3:
		await process_frame
	assert(arena.combat_over)
	assert(gs.current_floor()["wins"] == 1)
	assert(gs.active_charges == gs.ACTIVE_MAX_CHARGES)

	# Combat de gardien : un seul boss, butin garanti au sol, puis on change d'etage en partant.
	await create_timer(0.5).timeout
	gs.floor_index = 2
	gs.return_position = Vector2.ZERO
	gs.start_guardian_fight(false)
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	arena = current_scene
	assert(arena.is_boss_fight and get_nodes_in_group("mobs").size() == 1)
	for m in get_nodes_in_group("mobs"):
		m.take_hit(999)
	for i in 3:
		await process_frame
	assert(arena.waiting_to_leave and gs.floor_index == 2)
	var pickup = arena.get_children().filter(func(n): return "item_id" in n)[0]
	# Un actif au sol s'echange avec l'actif tenu, qui reste au sol.
	pickup.item_id = "oreiller_volant"
	pickup.player_near = true
	await _press(KEY_E)
	assert(gs.active_item_id == "oreiller_volant" and pickup.item_id == "reveil_strident")
	await create_timer(1.2).timeout
	assert(gs.floor_index == 3 and not gs.guardian_fight)

	# Mort : retour au menu, la partie continue 5 etages plus bas.
	await create_timer(0.5).timeout
	gs.floor_index = 7
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	current_scene.player.hp = 1
	current_scene.player.take_damage()
	await create_timer(1.8).timeout
	assert(current_scene.name == "MainMenu")
	assert(gs.run_started and gs.floor_index == 2 and gs.passive_count() == 0)

	print("test_arena OK")
	quit()
