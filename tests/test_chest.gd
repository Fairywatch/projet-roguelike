# Lancer : godot --headless --path . --script res://tests/test_chest.gd
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")

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
	assert(gs.passive_items.is_empty() and gs.active_item_id == "")

	gs.current_floor()["wins"] = chest.SEAL_WINS_REQUIRED
	chest._on_body_entered(player)
	assert(gs.current_floor()["opened_chests"] == [0])
	assert(gs.passive_items.size() + int(gs.active_item_id != "") == 1)

	chest._on_body_entered(player)
	assert(gs.current_floor()["opened_chests"] == [0])

	print("test_chest OK")
	player.free()
	quit()
