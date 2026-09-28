# Lancer : godot --headless --path . --script res://tests/test_difficulty.gd
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame  # laisse GameState._ready (chargement de la sauvegarde) passer avant la mise en place
	# Fichier a part : les tests ne touchent pas a la vraie sauvegarde du joueur.
	gs.save_path = "user://test_run.save"
	gs.new_run()

	gs.floor_index = 0
	gs.floor_data_by_index[0] = {"seed": 1, "family": FloorGenerator.Family.PARADOXAL, "intensity": 0}
	assert(is_equal_approx(gs.difficulty(), 1.0))
	gs.floor_data_by_index[0]["family"] = FloorGenerator.Family.PROFOND
	var profond_0: float = gs.difficulty()
	assert(profond_0 > 1.0)

	gs.floor_index = 8
	gs.floor_data_by_index[8] = {"seed": 1, "family": FloorGenerator.Family.PARADOXAL, "intensity": 0}
	assert(gs.difficulty() > profond_0)
	gs.floor_index = -3
	gs.floor_data_by_index[-3] = {"seed": 1, "family": FloorGenerator.Family.PARADOXAL, "intensity": 0}
	assert(gs.difficulty() > 1.0)

	var mob = load("res://scenes/combat/OmbreRampante.tscn").instantiate()
	root.add_child(mob)
	var telegraph: float = mob.telegraph_duration
	mob.apply_difficulty(2.0)
	assert(mob.hp == 6)
	assert(mob.telegraph_duration == telegraph)

	gs.floor_index = gs.TOWER_FLOOR_COUNT - 1
	assert(gs.is_last_floor())
	gs.run_started = true
	gs.take_item("plume_de_reve")
	gs.complete_tower()
	assert(gs.floor_index == 0 and gs.passive_count() == 0 and gs.floor_data_by_index.is_empty())
	assert(not gs.run_started and gs.after_combat_scene() == gs.MENU_PATH)
	gs.new_run()
	assert(gs.run_started and gs.after_combat_scene() == gs.return_map_path)

	# Passifs cumulables sans limite, leurs effets s'additionnent.
	assert(gs.take_item("plume_de_reve") == "")
	assert(gs.take_item("plume_de_reve") == "")
	assert(gs.take_item("oreiller_de_plumes") == "")
	assert(gs.passive_count() == 3 and gs.mod("max_hp") == 4)
	assert(is_equal_approx(gs.mod("speed"), -0.08))
	# Un seul actif : en prendre un rend l'ancien, sans toucher aux passifs.
	assert(gs.take_item("reveil_strident") == "")
	assert(gs.take_item("mouchoir_usage") == "reveil_strident")
	assert(gs.active_item_id == "mouchoir_usage" and gs.passive_count() == 3)
	for i in 30:
		assert(gs.roll_item_id() != gs.active_item_id)
	# Chaque passif ne declare que des effets connus du joueur ou de l'arene.
	var known := ["max_hp", "damage", "speed", "dash_cooldown", "attack_cooldown", "dash_length", "reach",
		"knockback", "heal_on_hit", "heal_on_kill", "crit", "evasion", "iframes", "extra_lives", "shield",
		"thorns", "active_recharge", "slow_on_hit", "dash_trail", "enemy_hp", "enemy_speed", "enemy_cooldown",
		"telegraph", "drop_chance", "encounter_rate"]
	for item in Items.PASSIVES:
		for stat in item["mods"]:
			assert(stat in known)
	gs.reset_run_items()

	# Chaque portail est garde : l'etage ne change qu'apres la victoire sur le gardien.
	gs.floor_index = 3
	gs.start_guardian_fight(false)
	assert(gs.floor_index == 3 and gs.guardian_fight)
	gs.take_guardian_exit()
	assert(gs.floor_index == 4 and not gs.guardian_fight)
	gs.floor_index = gs.TOWER_FLOOR_COUNT - 1
	gs.start_guardian_fight(false)
	gs.take_guardian_exit()
	assert(gs.floor_index == 0 and gs.menu_message.begins_with("Le reveur") and not gs.run_started)
	gs.start_guardian_fight(true)
	gs.take_guardian_exit()
	assert(gs.floor_index == -1)
	gs.floor_index = gs.MIN_FLOOR_INDEX
	gs.start_guardian_fight(true)
	gs.take_guardian_exit()
	assert(gs.floor_index == 0 and gs.pending_ground_item != "")

	# Etages petits au debut, grands a la fin, et toujours jouables (sortie + coffre).
	for seed in 20:
		var small := FloorGenerator.generate(seed % 2, 0, _rng(seed), 0.0)
		var big := FloorGenerator.generate(seed % 2, 0, _rng(seed), 1.0)
		assert(small.size == FloorGenerator.MIN_GRID and big.size == FloorGenerator.MAX_GRID)
		assert(small.floor_cells.size() < big.floor_cells.size())
		assert(small.exit_cell != small.spawn_cell and small.secondary_cell not in [small.spawn_cell, small.exit_cell])
		assert(not small.chest_cells.is_empty())

	# Sauvegarde de partie : tout l'etat de la run survit a un redemarrage du jeu.
	gs.new_run()
	gs.floor_index = 4
	gs.current_floor()["ground_items"].append({"id": "cafe_serre", "pos": Vector2(120, 340)})
	gs.take_item("plume_de_reve")
	gs.take_item("plume_de_reve")
	gs.take_item("oreiller_volant")
	gs.active_charges = 1
	gs.save_run()
	gs.new_run()
	gs.run_started = false
	gs.load_run()
	assert(gs.run_started and gs.floor_index == 4)
	assert(gs.passive_items == {"plume_de_reve": 2} and gs.mod("max_hp") == 2)
	assert(gs.active_item_id == "oreiller_volant" and gs.active_charges == 1)
	assert(gs.floor_data_by_index[4]["ground_items"][0]["pos"] == Vector2(120, 340))

	# Parametres : une option coupee le reste apres rechargement.
	var saved: bool = Settings.enabled("screen_shake")
	Settings.set_option("screen_shake", false)
	Settings.values["screen_shake"] = true
	Settings.load_settings()
	assert(not Settings.enabled("screen_shake"))
	Settings.set_option("screen_shake", saved)

	print("test_difficulty OK")
	quit()

func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
