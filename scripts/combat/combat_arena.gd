extends Node2D

const BAR_WIDTH := 100.0
const DROP_CHANCE := 0.45
const MAX_MOBS := 4
const FLOORS_PER_EXTRA_MOB := 4
const NEGATIVE_BOSS_CHANCE := 1.0 / 7.0
const ARENA_SIZE := Vector2(900, 540)
const SPAWN_MARGIN := 60.0
const MIN_SPAWN_DISTANCE := 220.0

# Gardiens de portail : pas le Songe papillon, trop rapide une fois renforce.
const GUARDIAN_POOL := [
	preload("res://scenes/combat/OmbreRampante.tscn"),
	preload("res://scenes/combat/Berceuse.tscn"),
	preload("res://scenes/combat/NounoursEgare.tscn"),
	preload("res://scenes/combat/VoixMurmurante.tscn"),
	preload("res://scenes/combat/EveilleurDePeur.tscn"),
]
const MOB_POOL := [
	preload("res://scenes/combat/OmbreRampante.tscn"),
	preload("res://scenes/combat/Berceuse.tscn"),
	preload("res://scenes/combat/NounoursEgare.tscn"),
	preload("res://scenes/combat/SongePapillon.tscn"),
	preload("res://scenes/combat/VoixMurmurante.tscn"),
	preload("res://scenes/combat/EveilleurDePeur.tscn"),
]
const NEGATIVE_FLOOR_MOB := preload("res://scenes/combat/TerreurNocturne.tscn")

@onready var player: CharacterBody2D = $PlayerCombat
@onready var background: Node2D = $Background
@onready var hp_bar_fill: ColorRect = $UI/HPBarBack/HPBarFill
@onready var hp_text: Label = $UI/HPBarBack/HPText
@onready var dash_bar_fill: ColorRect = $UI/DashBarBack/DashBarFill
@onready var mob_label: Label = $UI/MobLabel
@onready var active_label: Label = $UI/ActiveLabel
@onready var item_message_label: Label = $UI/ItemMessageLabel

var is_boss_fight := false
var combat_over := false
var message_serial := 0
var waiting_to_leave := false
var leaving := false

func _ready() -> void:
	player.died.connect(_on_player_died)
	player.item_message.connect(_on_item_message)
	$UI.add_child(InventoryPanel.new())

	var floor_meta := GameState.current_floor()
	DreamTheme.set_family(floor_meta["family"])
	background.setup(floor_meta["family"], floor_meta["intensity"])
	var ambient := CanvasModulate.new()
	# Arene moins sombre que l'exploration : les telegraphes doivent rester lisibles.
	ambient.color = DreamTheme.ambient_color(floor_meta["family"], floor_meta["intensity"]).lerp(Color.WHITE, 0.7)
	add_child(ambient)
	player.add_child(DreamTheme.make_ambient_particles(floor_meta["family"]))

	var scenes := _pick_mob_scenes()
	is_boss_fight = GameState.guardian_fight or scenes == [NEGATIVE_FLOOR_MOB]
	for scene in scenes:
		_spawn_mob(scene)

func _pick_mob_scenes() -> Array:
	if GameState.guardian_fight:
		# Le dernier portail de la nuit est garde par la Terreur nocturne.
		if GameState.is_last_floor() and not GameState.guardian_exit_down:
			return [NEGATIVE_FLOOR_MOB]
		return [GUARDIAN_POOL.pick_random()]
	if GameState.floor_index < 0 and randf() < NEGATIVE_BOSS_CHANCE:
		return [NEGATIVE_FLOOR_MOB]
	var count := mini(MAX_MOBS, 2 + abs(GameState.floor_index) / FLOORS_PER_EXTRA_MOB + randi() % 2)
	var scenes := []
	for i in count:
		scenes.append(MOB_POOL.pick_random())
	return scenes

func _spawn_mob(scene: PackedScene) -> void:
	var mob: CharacterBody2D = scene.instantiate()
	mob.position = _random_spawn_position()
	add_child(mob)
	mob.telegraph_duration *= 1.0 + GameState.mod("telegraph")
	if GameState.guardian_fight:
		mob.empower_as_guardian()
	mob.apply_difficulty(GameState.difficulty())
	# Passifs qui affaiblissent les ennemis (Marchand de sable, Montre a gousset...).
	mob.hp = maxi(1, ceili(mob.hp * (1.0 + GameState.mod("enemy_hp"))))
	mob.max_hp = mob.hp
	mob.chase_speed *= maxf(0.3, 1.0 + GameState.mod("enemy_speed"))
	mob.cooldown_duration *= maxf(0.3, 1.0 + GameState.mod("enemy_cooldown"))
	mob.died.connect(player.on_enemy_killed)

func _random_spawn_position() -> Vector2:
	var pos := Vector2.ZERO
	for i in 20:
		pos = Vector2(randf_range(SPAWN_MARGIN, ARENA_SIZE.x - SPAWN_MARGIN), randf_range(SPAWN_MARGIN, ARENA_SIZE.y - SPAWN_MARGIN))
		if pos.distance_to(player.position) >= MIN_SPAWN_DISTANCE:
			break
	return pos

func _alive_mobs() -> Array:
	return get_tree().get_nodes_in_group("mobs").filter(func(m): return m.state != BaseMob.State.DEAD)

func _process(_delta: float) -> void:
	hp_bar_fill.size.x = BAR_WIDTH * clampf(float(player.hp) / player.max_hp, 0.0, 1.0)
	hp_text.text = "%d / %d" % [max(player.hp, 0), player.max_hp]

	var dash_ratio: float = 1.0 - clampf(player.dash_cooldown_timer / player.dash_cooldown_effective, 0.0, 1.0)
	dash_bar_fill.size.x = BAR_WIDTH * dash_ratio

	active_label.text = "%s\nPassifs : %d  (Tab)" % [GameState.active_summary(), GameState.passive_count()]

	if combat_over:
		return
	var alive := _alive_mobs()
	if alive.is_empty():
		_on_victory()
	elif is_boss_fight:
		mob_label.text = "%s  PV %d" % ["Gardien du portail" if GameState.guardian_fight else "Terreur nocturne", alive[0].hp]
	else:
		mob_label.text = "Ennemis : %d" % alive.size()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameState.guardian_fight = false
		SceneTransition.change_scene(GameState.return_map_path)

func _unhandled_key_input(event: InputEvent) -> void:
	if waiting_to_leave and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_leave()

# duration <= 0 : le message reste affiche.
func _on_item_message(text: String, duration: float = 2.0) -> void:
	message_serial += 1
	var serial := message_serial
	item_message_label.text = text
	item_message_label.visible = true
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration).timeout
	if serial == message_serial:
		item_message_label.visible = false

func _on_victory() -> void:
	combat_over = true
	player.invincible = true
	if not GameState.guardian_fight:
		GameState.current_floor()["wins"] += 1
	GameState.recharge_active()
	mob_label.text = "Gardien vaincu !" if GameState.guardian_fight else "Victoire !"
	if is_boss_fight or randf() < DROP_CHANCE + GameState.mod("drop_chance"):
		_drop_item()
		return
	await get_tree().create_timer(1.4).timeout
	_leave()

# Le butin tombe au sol : on choisit de le prendre (E) ou de garder son objet (Entree).
func _drop_item() -> void:
	var pickup := ItemPickup.new()
	pickup.item_id = GameState.roll_item_id()
	pickup.position = player.position + Vector2(0, -80 if player.position.y > 150 else 80)
	add_child(pickup)
	pickup.taken.connect(_on_pickup_taken)
	waiting_to_leave = true
	_on_item_message("E : prendre l'objet   |   Entree : continuer", 0.0)

func _on_pickup_taken(_pickup: ItemPickup, taken_id: String, old_id: String) -> void:
	player.apply_items()
	var text := "Tu prends %s" % Items.find(taken_id)["name"]
	if old_id != "":
		text += " (tu laisses %s)" % Items.find(old_id)["name"]
	_on_item_message(text, 0.0)
	await get_tree().create_timer(1.0).timeout
	_leave()

func _leave() -> void:
	if leaving:
		return
	leaving = true
	if GameState.guardian_fight:
		GameState.take_guardian_exit()
	SceneTransition.change_scene(GameState.after_combat_scene())

func _on_player_died() -> void:
	combat_over = true
	GameState.guardian_fight = false
	mob_label.text = "Vaincu..."
	await get_tree().create_timer(1.0).timeout
	if GameState.floor_index < 0:
		GameState.apply_negative_death()
	else:
		GameState.apply_death_setback()
	SceneTransition.change_scene(GameState.MENU_PATH)
