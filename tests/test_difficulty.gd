# Lancer : godot --headless --path . --script res://tests/test_difficulty.gd
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame  # laisse GameState._ready (chargement de la sauvegarde) passer avant la mise en place
	# Fichier a part : les tests ne touchent pas a la vraie sauvegarde du joueur.
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.new_run(0)  # la sauvegarde de test peut venir d'une autre nuit

	# Z (position de W) fait monter, en plus des fleches.
	var z_key := InputEventKey.new()
	z_key.physical_keycode = KEY_W
	z_key.pressed = true
	Input.parse_input_event(z_key)
	await process_frame
	assert(Controls.move_vector() == Vector2.UP)
	z_key.pressed = false
	Input.parse_input_event(z_key)
	await process_frame
	assert(Controls.move_vector() == Vector2.ZERO)

	# PV perdus gardes d'un combat a l'autre ; une etoile en rend un ; un +PV max arrive plein.
	assert(gs.hp_lost == 0 and gs.current_hp() == gs.max_hp() and not gs.heal(1))
	gs.hp_lost = 2
	assert(gs.current_hp() == gs.max_hp() - 2)
	assert(gs.heal(1) and gs.hp_lost == 1)
	gs.take_item("plume_de_reve")
	assert(gs.current_hp() == gs.max_hp() - 1 and gs.max_hp() == gs.BASE_MAX_HP + 1)
	gs.hp_lost = 99
	assert(gs.current_hp() == 1)
	gs.new_run()
	assert(gs.hp_lost == 0)

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

	var mob := Bestiary.make("lundi/bailleur")
	root.add_child(mob)
	var telegraph: float = mob.telegraph_duration
	var base_hp: int = mob.hp
	mob.apply_difficulty(2.0)
	assert(mob.hp == ceili(base_hp * 2.0))
	assert(mob.telegraph_duration == telegraph)

	gs.floor_index = gs.floor_count() - 1
	assert(gs.is_last_floor())
	gs.run_started = true
	gs.take_item("plume_de_reve")
	gs.complete_tower()
	assert(gs.floor_index == 0 and gs.passive_count() == 0 and gs.floor_data_by_index.is_empty())
	# Fin de nuit racontee d'abord (scene de recit), puis retour au menu.
	assert(not gs.run_started and gs.after_combat_scene() == gs.CUTSCENE_PATH)
	gs.cutscene_id = ""
	assert(gs.after_combat_scene() == gs.MENU_PATH)
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
	gs.floor_index = gs.floor_count() - 1
	gs.start_guardian_fight(false)
	gs.take_guardian_exit()
	assert(gs.floor_index == 0 and gs.menu_message.begins_with("Le rêveur") and not gs.run_started)
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

	# Rarete : chaque objet en a une, et le butin s'ameliore avec l'etage atteint.
	for item in Items.PASSIVES + Items.ACTIVES:
		assert(item["rarity"] in [Items.COMMUN, Items.RARE, Items.LEGENDAIRE])
	var legendary_rate := func(quality: float) -> float:
		var count := 0
		for i in 3000:
			count += int(gs.roll_rarity(quality) == Items.LEGENDAIRE)
		return count / 3000.0
	assert(legendary_rate.call(0.0) < 0.05 and legendary_rate.call(1.0) > 0.1)
	gs.new_run()
	gs.floor_index = 0
	var low: float = gs.loot_quality()
	gs.floor_index = gs.floor_count() - 1
	gs.current_floor()["wins"] = 3
	assert(gs.loot_quality() > low and gs.loot_quality(gs.BOSS_LOOT_BONUS) > gs.loot_quality())

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

	# Nuits : chacune a ses etages, sa difficulte et sa part de cauchemars ; la suivante se debloque.
	gs.coins = 0
	gs.unlocked_towers = 1
	gs.start_bag.clear()
	gs.shop_offers.clear()
	# 7 nuits, du lundi au dimanche : chaque jour est plus long, plus dur, plus cauchemardesque.
	assert(Towers.LIST.size() == 7)
	for day in range(1, Towers.LIST.size()):
		for key in ["floors", "difficulty", "nightmare_chance", "reward"]:
			assert(Towers.LIST[day][key] > Towers.LIST[day - 1][key])
	gs.new_run(0)
	var monday_difficulty: float = gs.difficulty()
	var sunday := Towers.LIST.size() - 1
	gs.new_run(sunday)
	gs.floor_index = 0
	gs.current_floor()["family"] = FloorGenerator.Family.PARADOXAL
	assert(gs.floor_count() == Towers.LIST[sunday]["floors"] and gs.difficulty() > monday_difficulty)
	var nightmares := 0
	for i in 200:
		gs.floor_data_by_index.erase(0)
		nightmares += int(gs.current_floor()["intensity"] == FloorGenerator.Intensity.CAUCHEMAR)
	assert(nightmares > 170)
	gs.new_run(0)
	gs.floor_index = gs.floor_count() - 1
	gs.complete_tower()
	assert(gs.unlocked_towers == 2 and gs.coins == Towers.LIST[0]["reward"])
	assert(gs.menu_message.contains(Towers.LIST[1]["name"]))

	# Boutique : 3 offres distinctes ; achat hors partie = sac de depart de la prochaine nuit.
	gs.coins = 500
	var offers: Array = gs.get_shop_offers()
	assert(offers.size() == gs.SHOP_SIZE and offers.size() == Array(offers).reduce(func(acc, id): return acc + [id] if id not in acc else acc, []).size())
	var bought: String = offers[0]
	assert(gs.buy(0) and not gs.buy(0))
	assert(gs.coins == 500 - gs.shop_price(bought) and gs.start_bag == [bought])
	gs.new_run(0)
	assert(gs.passive_items.has(bought) and gs.start_bag.is_empty())
	gs.coins = 0
	assert(not gs.buy(1))

	# Speedrun : le chrono ne tourne qu'en mode speedrun ; a zero, la nuit s'arrete sans recompense.
	gs.new_run(0)
	assert(not gs.tick_speedrun(9999.0) and gs.run_started)
	gs.new_run(0, true)
	assert(is_equal_approx(gs.time_left, gs.floor_count() * gs.SPEEDRUN_SECONDS_PER_FLOOR))
	var coins_before: int = gs.coins
	assert(not gs.tick_speedrun(10.0) and is_equal_approx(gs.run_time, 10.0))
	assert(gs.tick_speedrun(gs.time_left + 1.0))
	assert(not gs.run_started and gs.coins == coins_before and gs.menu_message.begins_with("Le réveil sonne"))
	# Record enregistre en terminant une nuit en speedrun.
	gs.best_times.clear()
	gs.new_run(0, true)
	gs.tick_speedrun(42.0)
	gs.complete_tower()
	assert(is_equal_approx(gs.best_times[Towers.LIST[0]["id"]], 42.0) and gs.menu_message.contains("0:42"))

	# Quitter le jeu en plein combat compte comme une mort au redemarrage.
	gs.new_run(0)
	gs.floor_index = 7
	gs.take_item("plume_de_reve")
	gs.start_combat()
	gs.new_run(0)
	gs.load_run()
	assert(gs.floor_index == 2 and gs.passive_count() == 0 and not gs.in_combat)
	assert(gs.menu_message.begins_with("Tu as fui un combat"))
	# Un actif repose au sol garde ses charges : pas de recharge gratuite en le reprenant.
	gs.take_item("oreiller_volant")
	gs.active_charges = 1
	assert(gs.take_item("mouchoir_usage", 2) == "oreiller_volant" and gs.active_charges == 2)
	gs.take_item("oreiller_volant", 1)
	assert(gs.active_charges == 1)

	# Parametres : une option coupee le reste apres rechargement.
	var saved: bool = Settings.enabled("screen_shake")
	Settings.set_option("screen_shake", false)
	Settings.values["screen_shake"] = true
	Settings.load_settings()
	assert(not Settings.enabled("screen_shake"))
	Settings.set_option("screen_shake", saved)
	# Volumes : un curseur regle son bus audio, et 0 le coupe.
	var saved_sfx: float = Settings.volume("sfx_volume")
	Settings.set_option("sfx_volume", 0.5)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	assert(sfx_bus != -1 and is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), linear_to_db(0.5)))
	Settings.set_option("sfx_volume", 0.0)
	assert(AudioServer.is_bus_mute(sfx_bus))
	Settings.values["sfx_volume"] = 1.0
	Settings.load_settings()
	assert(Settings.volume("sfx_volume") == 0.0)
	Settings.set_option("sfx_volume", saved_sfx)

	print("test_difficulty OK")
	quit()

func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
