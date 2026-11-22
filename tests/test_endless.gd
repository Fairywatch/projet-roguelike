# Lancer : godot --headless --path . --script res://tests/test_endless.gd
# Tour sans fin : ouverte apres la premiere semaine, un lieu de nuit par etage, des creatures de
# toutes les nuits, pas de dernier etage, et la mort met fin a la partie avec un record.
extends SceneTree

func _mode_panel(hub: Node) -> ModePanel:
	for child in hub.get_node("UI").get_children():
		if child is ModePanel:
			return child
	return null

func _open(path: String) -> Node:
	change_scene_to_file(path)
	for i in 10:
		await process_frame
	return current_scene

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.upgrades = {}
	gs.start_bag.clear()
	gs.endless_best = -1
	gs.new_run(0)
	gs.run_started = false
	var endless: int = Towers.ENDLESS

	# Fermee pendant la premiere semaine.
	gs.week = 1
	var hub = await _open(gs.HUB_PATH)
	assert(hub.tower_state(endless) == "locked")
	hub._set_near("tower_%d" % endless)
	hub.interact()
	assert(not gs.run_started and not hub.panel_open)
	assert(hub.prompt_label.text.contains("sept nuits"))

	# Ouverte en semaine 2 : choix du mode, et jamais de speedrun (pas de reveil sans fin).
	gs.week = 2
	hub = await _open(gs.HUB_PATH)
	assert(hub.tower_state(endless) == "open")
	hub.speedrun_choice = true
	hub._set_near("tower_%d" % endless)
	hub.interact()
	_mode_panel(hub).chosen.emit(true)
	hub.speedrun_choice = false
	assert(gs.run_started and gs.is_endless() and not gs.speedrun and gs.nightmare_mode)
	assert(Towers.title(endless).begins_with("Tour sans fin"))

	# Un lieu de nuit par etage, jamais deux fois de suite le meme ; ennemis de toutes les nuits.
	var ids: Array = Towers.LIST.map(func(t): return t["id"])
	var previous := ""
	for index in 30:
		var data: Dictionary = gs.get_or_create_floor_data(index)
		assert(data["night"] in ids and data["night"] != previous)
		previous = data["night"]
	gs.floor_index = 4
	assert(gs.night() == gs.current_floor()["night"] and gs.mob_night() == Bestiary.ALL)
	assert(Bestiary.creatures(Bestiary.ALL).size() == Bestiary.NIGHTS.size() * 4)
	var boss: BaseMob = Bestiary.boss(Bestiary.ALL, false, gs.boss_history)
	var final: BaseMob = Bestiary.final_boss(Bestiary.ALL)
	assert(boss != null and final != null)
	boss.free()
	final.free()

	# Pas de dernier etage ; un boss tous les 3 etages, un boss final tous les 9.
	gs.floor_index = 60
	assert(not gs.is_last_floor())
	assert(gs.floor_has_boss(2) and not gs.floor_has_boss(3) and gs.floor_has_boss(5))
	assert(gs.endless_final_guardian(8) and gs.endless_final_guardian(17) and not gs.endless_final_guardian(5))
	assert(is_equal_approx(gs.night_progress(), 1.0))

	# La difficulte monte toujours, moitie moins vite apres ENDLESS_LATE_FLOOR.
	var levels := []
	for index in [0, 1, gs.ENDLESS_LATE_FLOOR, gs.ENDLESS_LATE_FLOOR + 2]:
		gs.floor_index = index
		gs.current_floor()["family"] = FloorGenerator.Family.PARADOXAL
		levels.append(gs.difficulty())
	assert(levels[0] < levels[1] and levels[1] < levels[2] and levels[2] < levels[3])
	assert(is_equal_approx(levels[1] - levels[0], gs.DIFFICULTY_PER_FLOOR))
	assert(is_equal_approx(levels[3] - levels[2], gs.DIFFICULTY_PER_FLOOR))  # 2 etages a mi-pente

	# La carte : lieu de la nuit tiree, record dans le HUD, pas de plongee vers les profondeurs.
	gs.floor_index = 0
	gs.return_position = Vector2.ZERO
	var map = await _open(gs.return_map_path)
	assert(map.night == gs.night())
	assert(map.place_text(0).contains("Tour sans fin") and not map.place_text(0).contains("/"))
	var portals := 0
	for node in map.get_node("Generated").get_children():
		if node.get("force_descend") != null:
			portals += 1
			assert(not node.force_descend)
	assert(portals == 1)

	# Gardien de l'etage 8 : le boss final d'une des nuits.
	gs.floor_index = 8
	gs.start_guardian_fight(false)
	var arena = await _open("res://scenes/combat/CombatArena.tscn")
	var bosses: Array = get_nodes_in_group("mobs").filter(func(m): return m.is_boss)
	var finals: Array = Bestiary.NIGHTS.values().map(func(n): return Bestiary.MOBS_DIR + n["final"] + ".gd")
	assert(arena.is_boss_fight and bosses.size() >= 1 and bosses[0].get_script().resource_path in finals)

	# Mort : la partie s'arrete, des pieces par etage atteint, et le record est garde.
	gs.coins = 0
	gs.floor_index = 7
	gs.apply_combat_death()
	assert(not gs.run_started and not gs.in_combat and not gs.guardian_fight)
	assert(gs.coins == 7 * gs.ENDLESS_COINS_PER_FLOOR and gs.endless_best == 7)
	assert(gs.menu_message.contains("étage 7"))
	gs.new_run(endless)
	gs.floor_index = 3
	gs.apply_combat_death()
	assert(gs.endless_best == 7 and gs.menu_message.contains("Record : étage 7"))
	gs.new_run(endless)
	gs.floor_index = 9
	gs.apply_combat_death()
	assert(gs.endless_best == 9 and gs.menu_message.contains("Nouveau record"))

	# Les nuits ordinaires n'ont pas change : dernier etage, pas de lieu tire.
	gs.week = 1
	gs.new_run(0)
	assert(not gs.is_endless() and gs.night() == "lundi" and not gs.current_floor().has("night"))
	gs.floor_index = gs.floor_count() - 1
	assert(gs.is_last_floor())
	gs.run_started = false
	gs.save_run()

	print("test_endless OK")
	quit()
