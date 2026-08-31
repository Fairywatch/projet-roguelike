extends Node2D

const BAR_WIDTH := 100.0

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

var mob: CharacterBody2D

func _ready() -> void:
	player.hp_changed.connect(_on_player_hp_changed)
	player.died.connect(_on_player_died)

	var mob_scene: PackedScene = _pick_mob_scene()
	mob = mob_scene.instantiate()
	mob.position = mob_spawn.position
	add_child(mob)
	mob.hp_changed.connect(_on_mob_hp_changed)
	mob.died.connect(_on_mob_died)

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
	var dash_cooldown_max: float = player.DASH_COOLDOWN
	var dash_ratio: float = 1.0 - clamp(dash_cooldown / dash_cooldown_max, 0.0, 1.0)
	dash_bar_fill.size.x = BAR_WIDTH * dash_ratio

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameState.guardian_fight = false
		SceneTransition.change_scene(GameState.return_map_path)

func _on_player_hp_changed(hp: int) -> void:
	hp_label.text = "PV: %d" % hp

func _on_mob_hp_changed(hp: int) -> void:
	mob_label.text = ("Gardien PV: %d" if GameState.guardian_fight else "Mob PV: %d") % hp

func _on_mob_died() -> void:
	var was_guardian := GameState.guardian_fight
	GameState.guardian_fight = false
	mob_label.text = "Gardien vaincu !" if was_guardian else "Mob vaincu !"
	await get_tree().create_timer(0.8).timeout
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
