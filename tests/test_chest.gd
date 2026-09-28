# Lancer : godot --headless --path . --script res://tests/test_chest.gd
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame  # laisse GameState._ready (chargement de la sauvegarde) passer avant la mise en place
	# Fichier a part : les tests ne touchent pas a la vraie sauvegarde du joueur.
	gs.save_path = "user://test_run.save"
	gs.new_run()

	for seed in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var data := FloorGenerator.generate(seed % 2, 0, rng)
		assert(data.chest_cells.size() == FloorGenerator.CHEST_COUNT)
		for cell in data.chest_cells:
			assert(data.floor_cells.has(cell))
			assert(cell not in [data.spawn_cell, data.exit_cell, data.secondary_cell])
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = seed
		assert(FloorGenerator.generate(seed % 2, 0, rng2).chest_cells == data.chest_cells)

	gs.floor_index = 0
	gs.reset_run_items()
	var player := Node2D.new()
	player.add_to_group("player")

	var chest = load("res://scenes/exploration/Chest.tscn").instantiate()
	chest.sealed = true
	root.add_child(chest)
	await process_frame
	chest._on_body_entered(player)
	assert(gs.current_floor()["opened_chests"].is_empty())
	assert(gs.passive_count() == 0 and gs.current_floor()["ground_items"].is_empty())

	gs.current_floor()["wins"] = chest.SEAL_WINS_REQUIRED
	chest._on_body_entered(player)
	assert(gs.current_floor()["opened_chests"] == [0])
	# L'objet n'est pas donne directement : il est pose au sol, a prendre ou non.
	assert(gs.passive_count() == 0 and not gs.has_active_item())
	assert(gs.current_floor()["ground_items"].size() == 1)

	chest._on_body_entered(player)
	assert(gs.current_floor()["opened_chests"] == [0])

	print("test_chest OK")
	player.free()
	quit()
