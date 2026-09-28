extends Node

const DEATH_SETBACK_FLOORS := 5
const MIN_FLOOR_INDEX := -10
const ACTIVE_MAX_CHARGES := 3
const TOWER_FLOOR_COUNT := 10
const ACTIVE_DROP_WEIGHT := 0.25
const DIFFICULTY_PER_FLOOR := 0.08
const PROFOND_DIFFICULTY_BONUS := 0.15

const MENU_PATH := "res://scenes/menu/MainMenu.tscn"
const SAVE_VERSION := 1
# Etat de la partie sauvegarde entre deux sessions (voir save_run / load_run).
const SAVED_FIELDS := [
	"floor_index", "floor_data_by_index", "negative_dive_available", "return_position",
	"run_started", "passive_items", "active_item_id", "active_charges", "next_fight_bonus_hp",
	"pending_ground_item",
]

var save_path := "user://run.save"

var return_map_path := "res://scenes/exploration/Map.tscn"
var return_position: Vector2 = Vector2.ZERO

var floor_index: int = 0
var floor_data_by_index: Dictionary = {}
var guardian_fight: bool = false
var guardian_exit_down: bool = false
var negative_dive_available: bool = true
var pending_message: String = ""
# Partie en cours : le menu propose alors "Continuer". Faux apres la fin d'une nuit.
var run_started: bool = false
var menu_message: String = ""

var passive_items: Dictionary = {}  # id -> nombre d'exemplaires
var mods: Dictionary = {}  # effets cumules des passifs
var active_item_id: String = ""
var active_charges: int = 0
var next_fight_bonus_hp: int = 0
# Objet a deposer au sol a l'arrivee sur la carte (butin des profondeurs).
var pending_ground_item: String = ""

func _ready() -> void:
	Settings.load_settings()
	load_run()

# Fermeture de la fenetre : on garde la partie (la carte met d'abord a jour la position du joueur).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_run()

# Sauvegarde a l'arrivee sur la carte ou au menu, et a la fermeture du jeu. Un combat en cours
# n'est pas sauvegarde : on reprend juste avant la rencontre.
func save_run() -> void:
	var data := {"version": SAVE_VERSION}
	for field in SAVED_FIELDS:
		data[field] = get(field)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_var(data)

func load_run() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	var data = file.get_var() if file else null
	if not (data is Dictionary) or data.get("version") != SAVE_VERSION:
		push_warning("Sauvegarde illisible ou d'une ancienne version, ignoree.")
		return
	for field in SAVED_FIELDS:
		if data.has(field):
			set(field, data[field])
	_recompute_mods()

func get_or_create_floor_data(index: int) -> Dictionary:
	if not floor_data_by_index.has(index):
		floor_data_by_index[index] = {
			"seed": randi(),
			"family": randi() % 2,
			"intensity": randi() % 2,
			"wins": 0,
			"opened_chests": [],
			"ground_items": [],
			"used_decor": [],
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

func new_run() -> void:
	floor_data_by_index.clear()
	floor_index = 0
	negative_dive_available = true
	guardian_fight = false
	return_position = Vector2.ZERO
	pending_message = ""
	pending_ground_item = ""
	reset_run_items()
	run_started = true

# Ou aller apres un combat : la carte, ou le menu si la nuit est terminee.
func after_combat_scene() -> String:
	return return_map_path if run_started else MENU_PATH

func complete_tower() -> void:
	floor_data_by_index.clear()
	floor_index = 0
	negative_dive_available = true
	return_position = Vector2.ZERO
	reset_run_items()
	run_started = false
	menu_message = "Le reveur se reveille... Nuit terminee !"

# Chaque portail est garde par un boss : on ne change d'etage qu'apres l'avoir vaincu.
func start_guardian_fight(going_down: bool) -> void:
	guardian_fight = true
	guardian_exit_down = going_down

func take_guardian_exit() -> void:
	guardian_fight = false
	if guardian_exit_down:
		if floor_index == MIN_FLOOR_INDEX:
			complete_negative_run()
		else:
			descend_floor()
	elif is_last_floor():
		complete_tower()
	else:
		advance_floor()

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
	menu_message = "Tu te reveilles en sursaut... Tu reprendras a l'etage %d, les mains vides." % floor_index

func apply_negative_death() -> void:
	for key in floor_data_by_index.keys():
		if key < 0:
			floor_data_by_index.erase(key)
	floor_index = 0
	negative_dive_available = false
	return_position = Vector2.ZERO
	menu_message = "Tu t'es perdu dans les profondeurs... le passage s'est referme pour de bon."
	reset_run_items()

func complete_negative_run() -> void:
	for key in floor_data_by_index.keys():
		if key < 0:
			floor_data_by_index.erase(key)
	floor_index = 0
	return_position = Vector2.ZERO
	pending_ground_item = Items.PASSIVES.pick_random()["id"]
	var bonus_name: String = Items.find_passive(pending_ground_item)["name"]
	pending_message = "Tu remontes des profondeurs avec un lourd butin : %s !" % bonus_name

func roll_item_id() -> String:
	if randf() < ACTIVE_DROP_WEIGHT:
		return Items.ACTIVES.filter(func(item): return item["id"] != active_item_id).pick_random()["id"]
	return Items.PASSIVES.pick_random()["id"]

# Somme d'un effet ("speed", "crit"...) sur tous les passifs possedes (voir Items.PASSIVES).
func mod(stat: String) -> float:
	return mods.get(stat, 0.0)

func add_passive_item(id: String) -> void:
	passive_items[id] = passive_items.get(id, 0) + 1
	_recompute_mods()

func _recompute_mods() -> void:
	mods.clear()
	for id in passive_items:
		var item_mods: Dictionary = Items.find_passive(id)["mods"]
		for stat in item_mods:
			mods[stat] = mods.get(stat, 0.0) + item_mods[stat] * passive_items[id]

func has_active_item() -> bool:
	return active_item_id != ""

# Prend un objet. Passif : s'ajoute aux autres. Actif : un seul a la fois, on renvoie
# l'ancien actif ("" si aucun) pour le laisser au sol.
func take_item(id: String) -> String:
	if not Items.is_active(id):
		add_passive_item(id)
		return ""
	var old := active_item_id
	active_item_id = id
	active_charges = ACTIVE_MAX_CHARGES
	return old

# Chaque combat gagne rend une charge a l'objet actif (facon Isaac).
func recharge_active() -> void:
	if has_active_item():
		active_charges = mini(ACTIVE_MAX_CHARGES, active_charges + 1 + int(mod("active_recharge")))

func reset_run_items() -> void:
	passive_items.clear()
	mods.clear()
	active_item_id = ""
	active_charges = 0
	next_fight_bonus_hp = 0

func active_summary() -> String:
	if not has_active_item():
		return "Aucun objet actif"
	var charges := "o".repeat(active_charges) + "-".repeat(ACTIVE_MAX_CHARGES - active_charges)
	return "E : %s  %s" % [Items.find_active(active_item_id)["name"], charges]

func passive_count() -> int:
	var total := 0
	for id in passive_items:
		total += passive_items[id]
	return total

func passives_detail() -> String:
	if passive_items.is_empty():
		return "Aucun objet passif."
	var lines: Array = []
	for id in passive_items:
		var item := Items.find_passive(id)
		var count: String = " x%d" % passive_items[id] if passive_items[id] > 1 else ""
		lines.append("%s%s : %s" % [item["name"], count, item["desc"]])
	return "
".join(lines)
