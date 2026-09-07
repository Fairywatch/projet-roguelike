extends Node2D

const BAR_WIDTH := 100.0
const DROP_CHANCE := 0.45
const ACTIVE_DROP_WEIGHT := 0.25
const TELEGRAPH_BONUS_PER_STACK := 0.25

const GuardianMobScene := preload("res://scenes/combat/OmbreRampante.tscn")
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
@onready var hp_label: Label = $UI/HPLabel
@onready var mob_label: Label = $UI/MobLabel
@onready var mob_spawn: Marker2D = $MobSpawn
@onready var attack_bar_fill: ColorRect = $UI/AttackBarBack/AttackBarFill
@onready var dash_bar_fill: ColorRect = $UI/DashBarBack/DashBarFill
@onready var items_label: Label = $UI/ItemsLabel
@onready var item_message_label: Label = $UI/ItemMessageLabel

var mob: CharacterBody2D
var is_boss_fight := false

func _ready() -> void:
	player.hp_changed.connect(_on_player_hp_changed)
	player.died.connect(_on_player_died)
	player.item_message.connect(_on_item_message)
	items_label.text = GameState.inventory_summary()

	var mob_scene: PackedScene = _pick_mob_scene()
	is_boss_fight = GameState.guardian_fight or mob_scene == NEGATIVE_FLOOR_MOB
	mob = mob_scene.instantiate()
	mob.position = mob_spawn.position
	add_child(mob)
	mob.hp_changed.connect(_on_mob_hp_changed)
	mob.died.connect(_on_mob_died)

	var telegraph_stacks: int = GameState.passive_items.get("oeil_qui_traine", 0)
	if telegraph_stacks > 0:
		mob.telegraph_duration *= (1.0 + TELEGRAPH_BONUS_PER_STACK * telegraph_stacks)

	if GameState.guardian_fight:
		mob.empower_as_guardian()
		mob_label.text = "Gardien PV: %d" % mob.hp
	else:
		mob_label.text = "Mob PV: %d" % mob.hp

func _pick_mob_scene() -> PackedScene:
	if GameState.guardian_fight:
		return GuardianMobScene
	if GameState.floor_index < 0:
		var pool := MOB_POOL + [NEGATIVE_FLOOR_MOB]
		return pool.pick_random()
	return MOB_POOL.pick_random()

func _process(_delta: float) -> void:
	var attack_cooldown: float = player.attack_cooldown_timer
	var attack_cooldown_max: float = player.ATTACK_COOLDOWN
	var attack_ratio: float = 1.0 - clamp(attack_cooldown / attack_cooldown_max, 0.0, 1.0)
	attack_bar_fill.size.x = BAR_WIDTH * attack_ratio

	var dash_cooldown: float = player.dash_cooldown_timer
	var dash_cooldown_max: float = player.dash_cooldown_effective
	var dash_ratio: float = 1.0 - clamp(dash_cooldown / dash_cooldown_max, 0.0, 1.0)
	dash_bar_fill.size.x = BAR_WIDTH * dash_ratio

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameState.guardian_fight = false
		SceneTransition.change_scene(GameState.return_map_path)

func _on_player_hp_changed(hp: int) -> void:
	hp_label.text = "PV: %d" % hp

func _on_item_message(text: String) -> void:
	item_message_label.text = text
	item_message_label.visible = true
	items_label.text = GameState.inventory_summary()
	await get_tree().create_timer(2.0).timeout
	item_message_label.visible = false

func _on_mob_hp_changed(hp: int) -> void:
	mob_label.text = ("Gardien PV: %d" if GameState.guardian_fight else "Mob PV: %d") % hp

func _maybe_drop_item() -> void:
	if not is_boss_fight and randf() >= DROP_CHANCE:
		return
	var grant_active: bool = GameState.active_item_id == "" and randf() < ACTIVE_DROP_WEIGHT
	var id: String
	if grant_active:
		id = Items.ACTIVES.pick_random()["id"]
	else:
		id = Items.PASSIVES.pick_random()["id"]
	player.obtain_item(id)

func _on_mob_died() -> void:
	var was_guardian := GameState.guardian_fight
	GameState.guardian_fight = false
	mob_label.text = "Gardien vaincu !" if was_guardian else "Mob vaincu !"
	_maybe_drop_item()
	await get_tree().create_timer(1.4).timeout
	if was_guardian:
		GameState.descend_floor()
	SceneTransition.change_scene(GameState.return_map_path)

func _on_player_died() -> void:
	GameState.guardian_fight = false
	hp_label.text = "PV: 0 - Vaincu..."
	await get_tree().create_timer(1.0).timeout
	if GameState.floor_index < 0:
		GameState.apply_negative_death()
	else:
		GameState.apply_death_setback()
	SceneTransition.change_scene(GameState.return_map_path)
