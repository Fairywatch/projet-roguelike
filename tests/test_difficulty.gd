# Lancer : godot --headless --path . --script res://tests/test_difficulty.gd
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")

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
	gs.add_passive_item("plume_de_reve")
	gs.complete_tower()
	assert(gs.floor_index == 0 and gs.passive_items.is_empty() and gs.floor_data_by_index.is_empty())

	print("test_difficulty OK")
	quit()
