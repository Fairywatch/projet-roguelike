extends Node

const BASE_MAX_HP := 3
const DEATH_SETBACK_FLOORS := 5
const MIN_FLOOR_INDEX := -10
const ACTIVE_MAX_CHARGES := 3
const ACTIVE_DROP_WEIGHT := 0.25
const DIFFICULTY_PER_FLOOR := 0.08
const LOOT_WINS_CAP := 4
const BOSS_LOOT_BONUS := 0.3
const SEALED_CHEST_LOOT_BONUS := 0.25
const QUEST_LOOT_BONUS := 0.3
const PROFOND_DIFFICULTY_BONUS := 0.15
# Meta-progression (GDD section 7) : pieces gagnees pendant les nuits, gardees a la mort.
const COINS_PER_WIN := 1
const COINS_PER_GUARDIAN := 3
const COINS_PER_QUEST := 2
const SHOP_SIZE := 3
const SHOP_PRICES := [15, 35, 80]  # commun, rare, legendaire
const SHOP_QUALITY := 0.5
# Mode speedrun (GDD section 6) : un chrono pour toute la nuit, qui ne tourne qu'en jeu.
const SPEEDRUN_SECONDS_PER_FLOOR := 75.0
const GAMEPLAY_SCENES := ["Map", "CombatArena"]

const MENU_PATH := "res://scenes/menu/MainMenu.tscn"
const HUB_PATH := "res://scenes/hub/Hub.tscn"
const CUTSCENE_PATH := "res://scenes/story/Cutscene.tscn"
const SAVE_VERSION := 1
# Etat de la partie sauvegarde entre deux sessions (voir save_run / load_run).
const SAVED_FIELDS := [
	"floor_index", "floor_data_by_index", "negative_dive_available", "return_position",
	"run_started", "passive_items", "active_item_id", "active_charges", "hp_lost",
	"pending_ground_item", "tower_index", "speedrun", "time_left", "run_time", "in_combat",
	"boss_history",
]
const META_FIELDS := ["coins", "unlocked_towers", "completed_towers", "start_bag", "shop_offers", "best_times", "intro_seen"]

var save_path := "user://run.save"
var meta_path := "user://meta.save"

var return_map_path := "res://scenes/exploration/Map.tscn"
var return_position: Vector2 = Vector2.ZERO

var tower_index: int = 0
var speedrun: bool = false
# Vrai pendant un combat : si le jeu redemarre avec ce drapeau, on a fui le combat en quittant.
var in_combat: bool = false
# Boss de portail deja tires dans la nuit en cours ("chemin|version", voir Bestiary.boss).
var boss_history: Array = []
var time_left: float = 0.0
var run_time: float = 0.0
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
# PV perdus pendant la nuit (facon Isaac) : ils restent perdus d'un combat a l'autre. On garde
# les PV perdus plutot que les PV restants pour qu'un +PV max donne un coeur plein.
var hp_lost: int = 0
# Objet a deposer au sol a l'arrivee sur la carte (butin des profondeurs).
var pending_ground_item: String = ""

# Meta-progression, sauvegardee a part (meta_path) : elle survit a la mort et aux nouvelles nuits.
var coins: int = 0
var unlocked_towers: int = 1
var completed_towers: Array = []  # ids des nuits deja terminees au moins une fois
var intro_seen: bool = false

# Scene de recit a jouer (scripts/story.gd) : "intro" ou "ending_<id de nuit>", puis cutscene_next.
var cutscene_id: String = ""
var cutscene_tower: int = 0
var cutscene_next: String = MENU_PATH
var start_bag: Array = []  # passifs achetes hors partie, donnes au debut de la prochaine nuit
var shop_offers: Array = []  # ids proposes par la boutique ; "" = deja vendu
var best_times: Dictionary = {}  # id de tour -> meilleur temps en mode speedrun (secondes)

func _ready() -> void:
	# Interpolation physique (project.godot) seulement pour le joueur et sa camera (leurs scenes la
	# reactivent) : fluide sur les ecrans 120/144 Hz, sans risquer de trainees quand un mob se teleporte.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Settings.load_settings()
	load_run()
	_load_fields(meta_path, META_FIELDS)

# Fermeture de la fenetre : on garde la partie (la carte met d'abord a jour la position du joueur).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_run()

# Sauvegarde a l'arrivee sur la carte ou au menu, et a la fermeture du jeu. Un combat en cours
# n'est pas sauvegarde : on reprend juste avant la rencontre.
func save_run() -> void:
	_save_fields(save_path, SAVED_FIELDS)
	save_meta()

func save_meta() -> void:
	_save_fields(meta_path, META_FIELDS)

func load_run() -> void:
	_load_fields(save_path, SAVED_FIELDS)
	_recompute_mods()
	if in_combat:
		apply_combat_death()
		menu_message = "Tu as fui un combat... le reve te rattrape. " + menu_message

func start_combat() -> void:
	if not run_started:  # scene d'arene lancee seule (F6 dans l'editeur) : rien a proteger
		return
	in_combat = true
	save_run()

func end_combat() -> void:
	in_combat = false

# Mort en combat : recul classique, ou perte du passage vers les profondeurs.
func apply_combat_death() -> void:
	in_combat = false
	guardian_fight = false
	if floor_index < 0:
		apply_negative_death()
	else:
		apply_death_setback()

func _save_fields(path: String, fields: Array) -> void:
	var data := {"version": SAVE_VERSION}
	for field in fields:
		data[field] = get(field)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_var(data)

func _load_fields(path: String, fields: Array) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var data = file.get_var() if file else null
	if not (data is Dictionary) or data.get("version") != SAVE_VERSION:
		push_warning("Sauvegarde illisible ou d'une ancienne version, ignoree : %s" % path)
		return
	for field in fields:
		if data.has(field):
			set(field, data[field])

func get_or_create_floor_data(index: int) -> Dictionary:
	if not floor_data_by_index.has(index):
		floor_data_by_index[index] = {
			"seed": randi(),
			"family": randi() % 2,
			"intensity": FloorGenerator.Intensity.CAUCHEMAR if randf() < tower()["nightmare_chance"] else FloorGenerator.Intensity.REVE,
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
	return 1.0 + abs(floor_index) * DIFFICULTY_PER_FLOOR + bonus + tower()["difficulty"]

func tower() -> Dictionary:
	return Towers.get_tower(tower_index)

func floor_count() -> int:
	return tower()["floors"]

func is_last_floor() -> bool:
	return floor_index == floor_count() - 1

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene and scene.name in GAMEPLAY_SCENES and tick_speedrun(delta):
		SceneTransition.change_scene(MENU_PATH)

# Avance le chrono ; renvoie true quand le temps est ecoule (la nuit est alors terminee).
func tick_speedrun(delta: float) -> bool:
	if not (run_started and speedrun):
		return false
	run_time += delta
	time_left -= delta
	if time_left > 0.0:
		return false
	_end_run()
	menu_message = "Le reveil sonne ! Le reveur s'est reveille avant la fin de %s." % tower()["name"]
	return true

func new_run(index: int = tower_index, speedrun_mode: bool = false) -> void:
	tower_index = index
	speedrun = speedrun_mode
	time_left = floor_count() * SPEEDRUN_SECONDS_PER_FLOOR
	run_time = 0.0
	floor_data_by_index.clear()
	floor_index = 0
	negative_dive_available = true
	guardian_fight = false
	return_position = Vector2.ZERO
	pending_message = ""
	pending_ground_item = ""
	reset_run_items()
	boss_history.clear()
	for id in start_bag:
		add_passive_item(id)
	start_bag.clear()
	run_started = true

# Ou aller apres un combat : la carte, ou le menu si la nuit est terminee.
func play_cutscene(id: String, next_scene: String) -> void:
	cutscene_id = id
	cutscene_tower = tower_index
	cutscene_next = next_scene
	SceneTransition.change_scene(CUTSCENE_PATH)

func after_combat_scene() -> String:
	if cutscene_id != "":  # fin de nuit a raconter avant le retour au menu
		return CUTSCENE_PATH
	return return_map_path if run_started else MENU_PATH

static func format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]

func _end_run() -> void:
	floor_data_by_index.clear()
	floor_index = 0
	negative_dive_available = true
	guardian_fight = false
	return_position = Vector2.ZERO
	reset_run_items()
	run_started = false
	shop_offers.clear()

func complete_tower() -> void:
	_end_run()
	coins += tower()["reward"]
	cutscene_id = "ending_" + tower()["id"]
	cutscene_tower = tower_index
	cutscene_next = MENU_PATH
	if tower()["id"] not in completed_towers:
		completed_towers.append(tower()["id"])
	menu_message = "Le reveur se reveille... %s terminee ! +%d pieces." % [tower()["name"], tower()["reward"]]
	if speedrun:
		var id: String = tower()["id"]
		menu_message += " Temps : %s." % format_time(run_time)
		if run_time < best_times.get(id, INF):
			best_times[id] = run_time
			menu_message += " Nouveau record !"
	if tower_index + 1 < Towers.LIST.size() and unlocked_towers <= tower_index + 1:
		unlocked_towers = tower_index + 2
		menu_message += " Nouvelle nuit debloquee : %s !" % Towers.get_tower(tower_index + 1)["name"]

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
	shop_offers.clear()

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

# Qualite du butin (GDD : double progression). Monte avec l'etage atteint dans la tour et avec
# les combats gagnes sur l'etage ; bonus selon la source (boss, coffre scelle, quete).
func loot_quality(bonus: float = 0.0) -> float:
	var in_tower := clampf(abs(floor_index) / float(floor_count() - 1), 0.0, 1.0)
	var in_floor := minf(current_floor()["wins"], LOOT_WINS_CAP) / float(LOOT_WINS_CAP)
	return in_tower * 0.6 + in_floor * 0.25 + bonus

# Poids commun / rare / legendaire : qualite 0 -> ~82/16/2 %, qualite 1 -> ~42/42/16 %.
func roll_rarity(quality: float) -> int:
	var weights: Array[float] = [1.0, 0.2 + quality * 0.8, 0.02 + quality * 0.35]
	var pick: float = randf() * (weights[0] + weights[1] + weights[2])
	for rarity in weights.size():
		pick -= weights[rarity]
		if pick < 0.0:
			return rarity
	return Items.COMMUN

func roll_item_id(quality_bonus: float = 0.0) -> String:
	var pool: Array = Items.PASSIVES
	if randf() < ACTIVE_DROP_WEIGHT:
		pool = Items.ACTIVES.filter(func(item): return item["id"] != active_item_id)
	var rarity := roll_rarity(loot_quality(quality_bonus))
	var candidates := pool.filter(func(item): return item["rarity"] == rarity)
	return (candidates if not candidates.is_empty() else pool).pick_random()["id"]

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
# charges : celles de l'actif ramasse (-1 = objet neuf, charges pleines).
func take_item(id: String, charges: int = -1) -> String:
	if not Items.is_active(id):
		add_passive_item(id)
		return ""
	var old := active_item_id
	active_item_id = id
	active_charges = ACTIVE_MAX_CHARGES if charges < 0 else charges
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
	hp_lost = 0

func max_hp() -> int:
	return maxi(1, BASE_MAX_HP + int(mod("max_hp")))

func current_hp() -> int:
	return clampi(max_hp() - hp_lost, 1, max_hp())

# Rend des PV perdus ; faux si on est deja au maximum.
func heal(amount: int) -> bool:
	if current_hp() >= max_hp():
		return false
	hp_lost = max_hp() - mini(max_hp(), current_hp() + amount)
	return true

func active_summary() -> String:
	if not has_active_item():
		return "Aucun objet actif"
	var charges := "o".repeat(active_charges) + "-".repeat(ACTIVE_MAX_CHARGES - active_charges)
	return "L : %s  %s" % [Items.find_active(active_item_id)["name"], charges]

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
		lines.append("[%s] %s%s : %s" % [Items.RARITY_NAMES[item["rarity"]], item["name"], count, item["desc"]])
	return "
".join(lines)

# --- Boutique (meta-progression) ---------------------------------------------------

func shop_price(id: String) -> int:
	return SHOP_PRICES[Items.rarity(id)]

# Offres renouvelees apres chaque mort ou fin de nuit.
func get_shop_offers() -> Array:
	if shop_offers.is_empty():
		while shop_offers.size() < SHOP_SIZE:
			var rarity := roll_rarity(SHOP_QUALITY)
			var candidates := Items.PASSIVES.filter(func(item): return item["rarity"] == rarity and item["id"] not in shop_offers)
			if not candidates.is_empty():
				shop_offers.append(candidates.pick_random()["id"])
	return shop_offers

# Achat : le passif rejoint la nuit en cours, ou le sac de depart de la prochaine nuit.
func buy(slot: int) -> bool:
	var id: String = get_shop_offers()[slot]
	if id == "" or coins < shop_price(id):
		return false
	coins -= shop_price(id)
	shop_offers[slot] = ""
	if run_started:
		add_passive_item(id)
	else:
		start_bag.append(id)
	save_run()
	return true
