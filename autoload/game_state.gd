extends Node

const BASE_MAX_HP := 3
const MAX_HP_CAP := 8  # PV max plafonnes, quels que soient les objets
# Contre le farm : au plus 3 objets gagnes en combats ordinaires par etage (au-dela, seulement
# des pieces). Gardiens, coffres, quetes et cristaux n'entrent pas dans ce compte.
const COMBAT_ITEMS_PER_FLOOR := 3
# Butin mystere : une part des objets tombe cache (icone "?"). Dedans, une fois sur deux une
# malediction, sinon un objet un peu meilleur que la normale (le pari vaut le coup).
const MYSTERY_CHANCE := 0.2
const MYSTERY_CURSE_CHANCE := 0.5
const MYSTERY_QUALITY_BONUS := 0.3
const DEATH_SETBACK_FLOORS := 2  # les nuits font 6 a 12 etages
# A la mort, on garde quelques passifs tires au hasard : repartir les mains vides au milieu d'une
# nuit etait presque injouable (3 a 5 PV perdus par combat pour 3 PV).
const DEATH_KEPT_ITEMS := 2
# Fuir un combat ordinaire coute des pieces, et les PV perdus le restent. On ne fuit pas un gardien.
const FLEE_COST := 3
const MIN_FLOOR_INDEX := -10
# Un portail sur trois est garde par un boss (et toujours le dernier) ; les autres par une meute
# menee par une elite. Un boss a chaque etage n'etait plus un evenement.
const GUARDIAN_EVERY := 3
const ACTIVE_MAX_CHARGES := 3
const ACTIVE_DROP_WEIGHT := 0.25
const DIFFICULTY_PER_FLOOR := 0.08
const LOOT_WINS_CAP := 4
const BOSS_LOOT_BONUS := 0.3
const SEALED_CHEST_LOOT_BONUS := 0.25
# Recompense de quete (on y passe du temps) : deux passifs au choix, au moins rares, jamais
# maudits ni mysteres, si possible pas deja possedes ; legendaire plus probable qu'ailleurs.
const QUEST_CHOICES := 2
const QUEST_LEGENDARY_BASE := 0.15
const QUEST_LEGENDARY_PER_QUALITY := 0.3
const PROFOND_DIFFICULTY_BONUS := 0.15
# Meta-progression (GDD section 7) : pieces gagnees pendant les nuits, gardees a la mort.
const COINS_PER_WIN := 1
const COINS_PER_GUARDIAN := 3
const COINS_PER_QUEST := 5
const SHOP_SIZE := 3
const SHOP_PRICES := [15, 35, 80]  # commun, rare, legendaire
const SHOP_QUALITY := 0.5
# Ameliorations permanentes (boutique) : gardees pour toujours, un prix par niveau.
const UPGRADES := [
	{"id": "coeur", "name": "Cœur solide", "desc": "+1 PV de départ", "prices": [40, 90]},
	{"id": "poches", "name": "Poches profondes", "desc": "Garde 1 objet de plus à la mort", "prices": [60, 120]},
	{"id": "doudou", "name": "Doudou de voyage", "desc": "Chaque nuit commence avec un objet commun", "prices": [50]},
	{"id": "marchande", "name": "Amie de la marchande", "desc": "Une offre de plus à la boutique", "prices": [45]},
]
# Une fois les sept nuits terminees, une nouvelle semaine commence : plus dure, mieux payee.
const WEEK_DIFFICULTY := 0.25
const WEEK_REWARD := 0.5
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
	"boss_history", "nightmare_mode", "curses", "legendaries_seen", "run_stats",
]
const META_FIELDS := ["coins", "unlocked_towers", "completed_towers", "start_bag", "shop_offers", "best_times", "intro_seen", "wanderer_hint_seen",
	"upgrades", "week", "tutorial_done"]

var save_path := "user://run.save"
var meta_path := "user://meta.save"
# Trois sauvegardes independantes (partie en cours + meta-progression chacune). La premiere garde
# les noms de fichiers d'origine : une sauvegarde d'avant les emplacements devient la sauvegarde 1.
const SLOT_COUNT := 3
var save_dir := "user://"
var slot := 0  # sauvegarde en cours (0 a SLOT_COUNT - 1), retenue dans <save_dir>slot.cfg
var _defaults: Dictionary = {}  # valeur de depart de chaque champ sauvegarde (nouvelle partie)

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
# Rencontre en cours sur la carte (cauchemar errant touche) : la creature qui mene le combat, et
# s'il a ete pris par surprise (embuscade : les ennemis commencent etourdis). Non sauvegardes.
var encounter_lead: String = ""
var wanderer_hint_seen := false  # explication des cauchemars errants, une fois par sauvegarde
var ambush: bool = false
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
# Maledictions en cours : [{"id", "floors"}], "floors" = etages restants (celui-ci compris).
var curses: Array = []
# Legendaires deja tires cette nuit : chacun ne tombe qu'une fois par nuit.
var legendaries_seen: Array = []
# Mode de la nuit, choisi a l'entree de la tour : Normal (moins d'ennemis par combat, certains
# ennemis plus lents a tirer) ou Cauchemar (la difficulte d'origine).
var nightmare_mode := false
# Objet a deposer au sol a l'arrivee sur la carte (butin des profondeurs).
var pending_ground_item: String = ""

# Meta-progression, sauvegardee a part (meta_path) : elle survit a la mort et aux nouvelles nuits.
var coins: int = 0
var unlocked_towers: int = 1
var completed_towers: Array = []  # ids des nuits deja terminees au moins une fois
var intro_seen: bool = false
var upgrades: Dictionary = {}  # id d'amelioration -> niveau achete
var week: int = 1  # semaine en cours (1 = la premiere)
var tutorial_done: bool = false
# Bilan de la nuit en cours : combats gagnes, ennemis vaincus, objets pris, morts, fuites.
var run_stats: Dictionary = {}

# Scene de recit a jouer (scripts/story.gd) : "intro" ou "ending_<id de nuit>", puis cutscene_next.
var cutscene_id: String = ""
var cutscene_tower: int = 0
var cutscene_next: String = MENU_PATH
var start_bag: Array = []  # passifs achetes hors partie, donnes au debut de la prochaine nuit
var shop_offers: Array = []  # ids proposes par la boutique ; "" = deja vendu
var best_times: Dictionary = {}  # id de tour -> meilleur temps en mode speedrun (secondes)
var pad_watch: PadWatch

# Les aides a l'ecran montrent les boutons de l'appareil utilise en dernier (clavier ou manette) :
# elles se reecrivent sur ce signal. A la manette, le curseur de la souris se cache.
signal input_device_changed

func _input(event: InputEvent) -> void:
	if Controls.note_device(event):
		_on_device_changed()
	elif event is InputEventMouseMotion and event.relative.length() > 2.0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_device_changed() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if Controls.using_gamepad else Input.MOUSE_MODE_VISIBLE
	input_device_changed.emit()

# Manette branchee : petit message. Debranchee en jouant : le jeu se met en pause (PadWatch).
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		pad_watch.connected(Input.get_joy_name(device))
		return
	if Controls.using_gamepad and device == Controls.pad_device:
		var others := Input.get_connected_joypads()
		if others.is_empty():
			Controls.using_gamepad = false
			pad_watch.disconnected()
		else:
			Controls._use_pad(others[0])
		_on_device_changed()

func _ready() -> void:
	# Interpolation physique (project.godot) seulement pour le joueur et sa camera (leurs scenes la
	# reactivent) : fluide sur les ecrans 120/144 Hz, sans risquer de trainees quand un mob se teleporte.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Controls.setup()
	pad_watch = PadWatch.new()
	add_child(pad_watch)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	Settings.load_settings()
	for field in SAVED_FIELDS + META_FIELDS:
		_defaults[field] = _copy(get(field))
	slot = _read_slot()
	_use_slot_paths()
	load_run()
	_load_fields(meta_path, META_FIELDS)

# --- Sauvegardes (emplacements) -------------------------------------------------------

func slot_paths(index: int) -> Array:
	var suffix := "" if index == 0 else "_%d" % (index + 1)
	return [save_dir + "run%s.save" % suffix, save_dir + "meta%s.save" % suffix]

func _use_slot_paths() -> void:
	var paths := slot_paths(slot)
	save_path = paths[0]
	meta_path = paths[1]

func _read_slot() -> int:
	var config := ConfigFile.new()
	if config.load(save_dir + "slot.cfg") != OK:
		return 0
	return clampi(int(config.get_value("save", "slot", 0)), 0, SLOT_COUNT - 1)

# Change de sauvegarde : la partie en cours est enregistree, puis l'autre est chargee (ou une
# nouvelle partie commence si l'emplacement est vide).
func select_slot(index: int) -> void:
	save_run()
	slot = clampi(index, 0, SLOT_COUNT - 1)
	var config := ConfigFile.new()
	config.set_value("save", "slot", slot)
	config.save(save_dir + "slot.cfg")
	_use_slot_paths()
	_reset_state()
	load_run()
	_load_fields(meta_path, META_FIELDS)

# Efface une sauvegarde : ses fichiers sont supprimes. Si c'est celle en cours, on repart de zero.
func erase_slot(index: int) -> void:
	for path in slot_paths(index):
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if index == slot:
		_reset_state()

func _reset_state() -> void:
	for field in _defaults:
		set(field, _copy(_defaults[field]))
	mods.clear()
	guardian_fight = false
	pending_message = ""
	menu_message = ""
	cutscene_id = ""

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value

# Resume d'une sauvegarde pour le menu, lu dans ses fichiers ("" : emplacement vide).
func slot_summary(index: int) -> String:
	var paths := slot_paths(index)
	var meta := _read_file(paths[1])
	var run := _read_file(paths[0])
	var started: bool = run.get("run_started", false)
	var fresh: bool = meta.get("coins", 0) == 0 and meta.get("completed_towers", []).is_empty() and meta.get("unlocked_towers", 1) <= 1 \
		and meta.get("upgrades", {}).is_empty() and meta.get("week", 1) <= 1
	if not started and fresh:
		return ""
	var text := "Semaine %d  ·  %d/%d nuits  ·  %d pièces" % [meta.get("week", 1), meta.get("completed_towers", []).size(), Towers.LIST.size(), meta.get("coins", 0)]
	if started:
		text += "  ·  %s, étage %d" % [Towers.get_tower(run.get("tower_index", 0))["name"], run.get("floor_index", 0)]
	return text

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var data = file.get_var() if file else null
	return data if data is Dictionary and data.get("version") == SAVE_VERSION else {}

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
		menu_message = "Tu as fui un combat... le rêve te rattrape. " + menu_message

func start_combat() -> void:
	if not run_started:  # scene d'arene lancee seule (F6 dans l'editeur) : rien a proteger
		return
	in_combat = true
	save_run()

func end_combat() -> void:
	in_combat = false

# Mort en combat : recul classique, ou perte du passage vers les profondeurs.
func apply_combat_death() -> void:
	note("deaths")
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
		push_warning("Sauvegarde illisible ou d'une ancienne version, ignorée : %s" % path)
		return
	for field in fields:
		if data.has(field):
			set(field, data[field])

# Ce qu'un etage retient en plus de sa generation (graine, famille, intensite).
const FLOOR_COUNTERS := {
	"wins": 0,
	"combat_items": 0,  # objets deja gagnes en combats ordinaires sur cet etage
	"opened_chests": [],
	"ground_items": [],
	"used_decor": [],
}

func get_or_create_floor_data(index: int) -> Dictionary:
	if not floor_data_by_index.has(index):
		floor_data_by_index[index] = {
			"seed": randi(),
			"family": randi() % 2,
			"intensity": FloorGenerator.Intensity.CAUCHEMAR if randf() < tower()["nightmare_chance"] else FloorGenerator.Intensity.REVE,
		}
	var data: Dictionary = floor_data_by_index[index]
	# Les compteurs sont completes a chaque lecture : un etage enregistre avant l'ajout d'une cle
	# (partie commencee avec une version plus ancienne du jeu) la recoit ici au lieu de planter.
	for key in FLOOR_COUNTERS:
		if not data.has(key):
			data[key] = _copy(FLOOR_COUNTERS[key])
	return data

func current_floor() -> Dictionary:
	return get_or_create_floor_data(floor_index)

# Palier (numero d'etage, profondeur comprise pour les etages negatifs) + surcouche de type.
func difficulty() -> float:
	var family: int = current_floor()["family"]
	var bonus := PROFOND_DIFFICULTY_BONUS if family == FloorGenerator.Family.PROFOND else 0.0
	return 1.0 + abs(floor_index) * DIFFICULTY_PER_FLOOR + bonus + tower()["difficulty"] + (week - 1) * WEEK_DIFFICULTY

func tower_reward() -> int:
	return roundi(tower()["reward"] * (1.0 + (week - 1) * WEEK_REWARD))

# Compte un evenement dans le bilan de la nuit ("wins", "kills", "items", "deaths", "fled").
func note(stat: String, amount: int = 1) -> void:
	run_stats[stat] = run_stats.get(stat, 0) + amount

func run_summary() -> String:
	var deaths: int = run_stats.get("deaths", 0)
	return "Bilan : %d combat%s gagné%s, %d ennemi%s vaincu%s, %d objet%s, %s, en %s." % [
		run_stats.get("wins", 0), _s(run_stats.get("wins", 0)), _s(run_stats.get("wins", 0)),
		run_stats.get("kills", 0), _s(run_stats.get("kills", 0)), _s(run_stats.get("kills", 0)),
		run_stats.get("items", 0), _s(run_stats.get("items", 0)),
		"sans mourir" if deaths == 0 else "%d mort%s" % [deaths, _s(deaths)], format_time(run_time)]

static func _s(count: int) -> String:
	return "s" if count > 1 else ""

# --- Ameliorations permanentes ------------------------------------------------------

func upgrade_level(id: String) -> int:
	return upgrades.get(id, 0)

# Prix du prochain niveau, ou -1 si l'amelioration est au maximum.
func upgrade_price(id: String) -> int:
	for upgrade in UPGRADES:
		if upgrade["id"] == id:
			var level := upgrade_level(id)
			return upgrade["prices"][level] if level < upgrade["prices"].size() else -1
	return -1

func buy_upgrade(id: String) -> bool:
	var price := upgrade_price(id)
	if price < 0 or coins < price:
		return false
	coins -= price
	upgrades[id] = upgrade_level(id) + 1
	if id == "marchande":
		shop_offers.clear()  # la nouvelle offre apparait tout de suite
	save_meta()
	return true

# Premier combat du jeu : un tutoriel (scripts/ui/tutorial.gd). Pas pendant les tests sans fenetre.
func needs_tutorial() -> bool:
	return not tutorial_done and completed_towers.is_empty() and tower_index == 0 and floor_index == 0 \
		and not guardian_fight and DisplayServer.get_name() != "headless"

func tower() -> Dictionary:
	return Towers.get_tower(tower_index)

func floor_count() -> int:
	return tower()["floors"]

func is_last_floor() -> bool:
	return floor_index == floor_count() - 1

# Vrai si le portail de cet etage est garde par un boss (sinon : une meute menee par une elite).
func floor_has_boss(index: int = floor_index) -> bool:
	if index < 0:
		return index == MIN_FLOOR_INDEX or -index % GUARDIAN_EVERY == 0
	return index == floor_count() - 1 or (index + 1) % GUARDIAN_EVERY == 0

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene and scene.name in GAMEPLAY_SCENES and tick_speedrun(delta):
		SceneTransition.change_scene(MENU_PATH)

# Avance le chrono ; renvoie true quand le temps est ecoule (la nuit est alors terminee).
func tick_speedrun(delta: float) -> bool:
	if not run_started:
		return false
	run_time += delta  # le temps de jeu compte toujours (bilan de fin de nuit)
	if not speedrun:
		return false
	time_left -= delta
	if time_left > 0.0:
		return false
	_end_run()
	menu_message = "Le réveil sonne ! Le rêveur s'est réveillé avant la fin de %s." % tower()["name"]
	return true

func new_run(index: int = tower_index, speedrun_mode: bool = false, nightmare: bool = false) -> void:
	tower_index = index
	speedrun = speedrun_mode
	nightmare_mode = nightmare
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
	legendaries_seen.clear()
	run_stats.clear()
	if upgrade_level("doudou") > 0:  # Doudou de voyage : un objet commun pour commencer
		add_passive_item(Items.PASSIVES.filter(func(item): return item["rarity"] == Items.COMMUN).pick_random()["id"])
	for id in start_bag:
		add_passive_item(id)
		_note_legendary(id)
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
	var summary := run_summary()
	_end_run()
	coins += tower_reward()
	cutscene_id = "ending_" + tower()["id"]
	cutscene_tower = tower_index
	cutscene_next = MENU_PATH
	if tower()["id"] not in completed_towers:
		completed_towers.append(tower()["id"])
	menu_message = "Le rêveur se réveille... %s terminée ! +%d pièces." % [tower()["name"], tower_reward()]
	if speedrun:
		var id: String = tower()["id"]
		menu_message += " Temps : %s." % format_time(run_time)
		if run_time < best_times.get(id, INF):
			best_times[id] = run_time
			menu_message += " Nouveau record !"
	if tower_index + 1 < Towers.LIST.size() and unlocked_towers <= tower_index + 1:
		unlocked_towers = tower_index + 2
		menu_message += " Nouvelle nuit débloquée : %s !" % Towers.get_tower(tower_index + 1)["name"]
	menu_message += "\n" + summary
	# Le dimanche boucle la semaine : la suivante recommence au lundi, plus dure et mieux payee.
	if tower_index == Towers.LIST.size() - 1 and completed_towers.size() >= Towers.LIST.size():
		week += 1
		completed_towers.clear()
		menu_message += "\nLa semaine est finie... et une autre commence. Semaine %d : des nuits plus dures, de plus belles récompenses." % week

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
	_tick_curses()

func descend_floor() -> void:
	floor_index = max(MIN_FLOOR_INDEX, floor_index - 1)
	return_position = Vector2.ZERO
	_tick_curses()

# Un etage de passe : chaque malediction perd un etage, et s'efface a zero.
func _tick_curses() -> void:
	for curse in curses:
		curse["floors"] -= 1
	curses = curses.filter(func(curse): return curse["floors"] > 0)
	_recompute_mods()

func apply_death_setback() -> void:
	var new_index: int = max(0, floor_index - DEATH_SETBACK_FLOORS)
	for key in floor_data_by_index.keys():
		if key > new_index:
			floor_data_by_index.erase(key)
	floor_index = new_index
	return_position = Vector2.ZERO
	var kept := lose_items_on_death()
	menu_message = "Tu te réveilles en sursaut... Tu reprendras à l'étage %d, %s." % [floor_index, kept]
	shop_offers.clear()

func apply_negative_death() -> void:
	for key in floor_data_by_index.keys():
		if key < 0:
			floor_data_by_index.erase(key)
	floor_index = 0
	negative_dive_available = false
	return_position = Vector2.ZERO
	menu_message = "Tu t'es perdu dans les profondeurs... le passage s'est refermé pour de bon. Il te reste %s." % lose_items_on_death().trim_prefix("avec ")

func complete_negative_run() -> void:
	for key in floor_data_by_index.keys():
		if key < 0:
			floor_data_by_index.erase(key)
	floor_index = 0
	return_position = Vector2.ZERO
	pending_ground_item = Items.PASSIVES.filter(func(item): return item["id"] not in legendaries_seen).pick_random()["id"]
	_note_legendary(pending_ground_item)
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
	pool = pool.filter(func(item): return item["id"] not in legendaries_seen)
	var rarity := roll_rarity(loot_quality(quality_bonus))
	var candidates: Array = []
	while candidates.is_empty() and rarity >= Items.COMMUN:  # legendaires epuises : un cran en dessous
		candidates = pool.filter(func(item): return item["rarity"] == rarity)
		rarity -= 1
	var id: String = (candidates if not candidates.is_empty() else pool).pick_random()["id"]
	_note_legendary(id)
	return id

# Butin a poser au sol : {"id", "hidden"} (objet mystere ou non), ou {} sous "Poches trouees".
func roll_drop(quality_bonus: float = 0.0) -> Dictionary:
	if mod("no_loot") > 0.0:
		return {}
	if randf() >= MYSTERY_CHANCE:
		return {"id": roll_item_id(quality_bonus), "hidden": false}
	if randf() < MYSTERY_CURSE_CHANCE:
		return {"id": Items.CURSES.pick_random()["id"], "hidden": true}
	return {"id": roll_item_id(quality_bonus + MYSTERY_QUALITY_BONUS), "hidden": true}

# Deux passifs differents (voir QUEST_CHOICES) ; [] sous "Poches trouees".
func roll_quest_rewards() -> Array:
	if mod("no_loot") > 0.0:
		return []
	var legendary_chance := QUEST_LEGENDARY_BASE + loot_quality() * QUEST_LEGENDARY_PER_QUALITY
	var picks := []
	for i in QUEST_CHOICES:
		var rarity := Items.LEGENDAIRE if randf() < legendary_chance else Items.RARE
		var pool: Array = []
		while pool.is_empty() and rarity >= Items.RARE:  # legendaires epuises : un rare
			pool = Items.PASSIVES.filter(func(item): return item["rarity"] == rarity and item["id"] not in legendaries_seen and item["id"] not in picks)
			rarity -= 1
		var fresh := pool.filter(func(item): return item["id"] not in passive_items)
		var id: String = (fresh if not fresh.is_empty() else pool).pick_random()["id"]
		picks.append(id)
		_note_legendary(id)
	return picks

# Un legendaire laisse de cote (choix de quete) peut retomber plus tard dans la nuit.
func forget_legendary(id: String) -> void:
	if id not in passive_items:
		legendaries_seen.erase(id)

func _note_legendary(id: String) -> void:
	if Items.find(id).get("rarity", Items.COMMUN) == Items.LEGENDAIRE and id not in legendaries_seen:
		legendaries_seen.append(id)

# Apres une mort : les legendaires perdus peuvent retomber, sauf ceux encore poses au sol.
func _recount_legendaries() -> void:
	legendaries_seen.clear()
	for id in passive_items:
		_note_legendary(id)
	for data in floor_data_by_index.values():
		for entry in data.get("ground_items", []):
			_note_legendary(entry["id"])

# Somme d'un effet ("speed", "crit"...) sur tous les passifs possedes (voir Items.PASSIVES).
func mod(stat: String) -> float:
	return mods.get(stat, 0.0)

func add_passive_item(id: String) -> void:
	var count: int = passive_items.get(id, 0)
	if Items.find_passive(id).has("style"):
		passive_items.erase(id)  # remis a la fin : le dernier style pris est le style actif
	passive_items[id] = count + 1
	_recompute_mods()

func _recompute_mods() -> void:
	mods.clear()
	for id in passive_items:
		var item_mods: Dictionary = Items.find_passive(id)["mods"]
		for stat in item_mods:
			mods[stat] = mods.get(stat, 0.0) + item_mods[stat] * passive_items[id]
	for curse in curses:
		var curse_mods: Dictionary = Items.find_curse(curse["id"])["mods"]
		for stat in curse_mods:
			mods[stat] = mods.get(stat, 0.0) + curse_mods[stat]

func has_active_item() -> bool:
	return active_item_id != ""

# Prend un objet. Passif : s'ajoute aux autres. Actif : un seul a la fois, on renvoie
# l'ancien actif ("" si aucun) pour le laisser au sol.
# charges : celles de l'actif ramasse (-1 = objet neuf, charges pleines).
func take_item(id: String, charges: int = -1) -> String:
	ItemBanner.show_item(id)  # banniere facon Isaac : nom, tier et effet de l'objet
	if Items.is_curse(id):  # objet maudit : la malediction dure quelques etages
		curses.append({"id": id, "floors": Items.CURSE_FLOORS})
		_recompute_mods()
		return ""
	note("items")
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

# Mort : l'objet actif, les maledictions et la plupart des passifs sont perdus ; on en garde
# kept_on_death() au hasard. Renvoie ce qu'il reste, pour le message ("les mains vides", "avec ...").
func lose_items_on_death() -> String:
	var owned: Array = []
	for id in passive_items:
		for i in passive_items[id]:
			owned.append(id)
	owned.shuffle()
	var kept: Array = owned.slice(0, kept_on_death())
	reset_run_items()
	for id in kept:
		add_passive_item(id)
	_recount_legendaries()
	if kept.is_empty():
		return "les mains vides"
	return "avec " + " et ".join(kept.map(func(id): return Items.find_passive(id)["name"]))

func kept_on_death() -> int:
	return DEATH_KEPT_ITEMS + upgrade_level("poches")

func reset_run_items() -> void:
	passive_items.clear()
	curses.clear()
	mods.clear()
	active_item_id = ""
	active_charges = 0
	hp_lost = 0

func max_hp() -> int:
	return clampi(BASE_MAX_HP + upgrade_level("coeur") + int(mod("max_hp")), 1, MAX_HP_CAP)

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
	return "%s : %s  %s" % [Controls.name_of("active"), Items.find_active(active_item_id)["name"], charges]

func passive_count() -> int:
	var total := 0
	for id in passive_items:
		total += passive_items[id]
	return total

# Objets gagnes en combats ordinaires sur cet etage : au plus COMBAT_ITEMS_PER_FLOOR.
func combat_items_left() -> int:
	return maxi(0, COMBAT_ITEMS_PER_FLOOR - int(current_floor().get("combat_items", 0)))

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
		while shop_offers.size() < SHOP_SIZE + upgrade_level("marchande"):
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
