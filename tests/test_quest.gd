# Lancer : godot --headless --path . --script res://tests/test_quest.gd
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame  # laisse GameState._ready (chargement de la sauvegarde) passer avant la mise en place
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.new_run()

	# Les PNJ ont une salle a eux et un objet perdu loin d'eux, sur les grands comme les petits etages.
	var with_npc := 0
	for seed in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var data := FloorGenerator.generate(seed % 2, 0, rng, float(seed % 3) / 2.0)
		if data.npc_cell == FloorGenerator.NONE:
			continue
		with_npc += 1
		assert(data.floor_cells.has(data.npc_cell) and data.floor_cells.has(data.quest_cell))
		assert(data.npc_cell not in [data.spawn_cell, data.exit_cell, data.secondary_cell] + data.chest_cells)
		assert(data.quest_cell != data.npc_cell)
	assert(with_npc > 15)

	# Quete de chasse : acceptee, puis terminee apres N victoires, recompense au sol.
	var quest := {"npc": 0, "kind": "chasse", "target": 2, "state": "offered", "start_wins": 0, "carried": false}
	gs.current_floor()["wins"] = 1
	var npc = load("res://scripts/exploration/npc.gd").new()  # charge apres les autoloads
	npc.quest = quest
	root.add_child(npc)
	await process_frame
	npc.talk()
	assert(quest["state"] == "active" and quest["start_wins"] == 1 and not npc.is_complete())
	gs.current_floor()["wins"] = 3
	assert(npc.is_complete())
	npc.talk()
	assert(quest["state"] == "done" and gs.current_floor()["ground_items"].size() == 1)

	# Objet perdu : termine des que l'objet est porte.
	var lost := {"npc": 1, "kind": "objet_perdu", "target": 2, "state": "active", "start_wins": 0, "carried": false}
	npc.quest = lost
	assert(not npc.is_complete())
	lost["carried"] = true
	assert(npc.is_complete())

	print("test_quest OK")
	quit()
