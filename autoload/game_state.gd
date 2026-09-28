extends Node

const DEATH_SETBACK_FLOORS := 5
const MIN_FLOOR_INDEX := -10
const ACTIVE_MAX_CHARGES := 3
const TOWER_FLOOR_COUNT := 10
const ACTIVE_DROP_WEIGHT := 0.25
const DIFFICULTY_PER_FLOOR := 0.08
const PROFOND_DIFFICULTY_BONUS := 0.15

var return_map_path := "res://scenes/exploration/Map.tscn"
var return_position: Vector2 = Vector2.ZERO

var floor_index: int = 0
var floor_data_by_index: Dictionary = {}
var guardian_fight: bool = false
var negative_dive_available: bool = true
var pending_message: String = ""

var passive_items: Dictionary = {}
var active_item_id: String = ""
var active_charges: int = 0

func get_or_create_floor_data(index: int) -> Dictionary:
	if not floor_data_by_index.has(index):
		floor_data_by_index[index] = {
			"seed": randi(),
			"family": randi() % 2,
			"intensity": randi() % 2,
			"wins": 0,
			"opened_chests": [],
		}
	return floor_data_by_index[index]

func current_floor() -> Dictionary:
	return get_or_create_floor_data(floor_index)

# Palier (numero d'etage, profondeur comprise pour les etages negatifs) + surcouche de type.
func difficulty() -> float:
	var family: int = current_floor()["family"]
	var bonus := PROFOND_DIFFICULTY_BONUS if family == FloorGenerator.Family.PROFOND else 0.0
	return 1.0 + abs(floor_index) * DIFFICULTY_PER_FLOOR + bonus

func is_last_floor() -> bool:
	return floor_index == TOWER_FLOOR_COUNT - 1

func complete_tower() -> void:
	floor_data_by_index.clear()
	floor_index = 0
	negative_dive_available = true
	return_position = Vector2.ZERO
	reset_run_items()
	pending_message = "Le reveur se reveille... Nuit terminee ! Une nouvelle nuit commence."

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
	reset_run_items()

func apply_negative_death() -> void:
	for key in floor_data_by_index.keys():
		if key < 0:
			floor_data_by_index.erase(key)
	floor_index = 0
	negative_dive_available = false
	return_position = Vector2.ZERO
	pending_message = "Tu t'es perdu dans les profondeurs... le passage s'est refermé pour de bon."
	reset_run_items()

func complete_negative_run() -> void:
	for key in floor_data_by_index.keys():
		if key < 0:
			floor_data_by_index.erase(key)
	floor_index = 0
	return_position = Vector2.ZERO
	var bonus_id: String = Items.PASSIVES.pick_random()["id"]
	add_passive_item(bonus_id)
	var bonus_name: String = Items.find_passive(bonus_id)["name"]
	pending_message = "Tu remontes des profondeurs avec un lourd butin : %s !" % bonus_name

func roll_item_id() -> String:
	if active_item_id == "" and randf() < ACTIVE_DROP_WEIGHT:
		return Items.ACTIVES.pick_random()["id"]
	return Items.PASSIVES.pick_random()["id"]

func grant_item(id: String) -> void:
	if Items.find_active(id).is_empty():
		add_passive_item(id)
	else:
		set_active_item(id)

func add_passive_item(id: String) -> void:
	passive_items[id] = passive_items.get(id, 0) + 1

func set_active_item(id: String) -> void:
	active_item_id = id
	active_charges = ACTIVE_MAX_CHARGES

func reset_run_items() -> void:
	passive_items.clear()
	active_item_id = ""
	active_charges = 0

func inventory_summary() -> String:
	if passive_items.is_empty() and active_item_id == "":
		return "Objets: aucun"
	var parts: Array = []
	for id in passive_items.keys():
		var item := Items.find_passive(id)
		parts.append("%s x%d" % [item.get("name", id), passive_items[id]])
	var text := "Objets: " + (", ".join(parts) if not parts.is_empty() else "aucun")
	if active_item_id != "":
		var active_item := Items.find_active(active_item_id)
		text += " | Actif: %s (%d)" % [active_item.get("name", active_item_id), active_charges]
	return text
