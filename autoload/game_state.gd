extends Node

const DEATH_SETBACK_FLOORS := 5
const MIN_FLOOR_INDEX := -10

var return_map_path := "res://scenes/exploration/Map.tscn"
var return_position: Vector2 = Vector2.ZERO

var floor_index: int = 0
var floor_data_by_index: Dictionary = {}
var guardian_fight: bool = false
var negative_dive_available: bool = true
var pending_message: String = ""

func get_or_create_floor_data(index: int) -> Dictionary:
	if not floor_data_by_index.has(index):
		floor_data_by_index[index] = {
			"seed": randi(),
			"family": randi() % 2,
			"intensity": randi() % 2,
		}
	return floor_data_by_index[index]

func advance_floor() -> void:
	floor_index += 1
	return_position = Vector2.ZERO

func descend_floor() -> void:
	floor_index = max(MIN_FLOOR_INDEX, floor_index - 1)
	return_position = Vector2.ZERO

func apply_death_setback() -> void:
	var new_index: int = max(0, floor_index - DEATH_SETBACK_FLOORS)
	for key in floor_data_by_index.keys():
		if key > new_index:
			floor_data_by_index.erase(key)
	floor_index = new_index
	return_position = Vector2.ZERO

func apply_negative_death() -> void:
	for key in floor_data_by_index.keys():
		if key < 0:
			floor_data_by_index.erase(key)
	floor_index = 0
	negative_dive_available = false
	return_position = Vector2.ZERO
	pending_message = "Tu t'es perdu dans les profondeurs... le passage s'est refermé pour de bon."

func complete_negative_run() -> void:
	for key in floor_data_by_index.keys():
		if key < 0:
			floor_data_by_index.erase(key)
	floor_index = 0
	return_position = Vector2.ZERO
	pending_message = "Tu remontes des profondeurs avec un lourd butin... (loot a venir)"
