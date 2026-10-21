extends Node2D

const DROP_CHANCE := 0.45
const MAX_MOBS := 4
const FLOORS_PER_EXTRA_MOB := 4
const NEGATIVE_BOSS_CHANCE := 1.0 / 7.0
const ARENA_SIZE := Vector2(900, 540)
const SPAWN_MARGIN := 60.0
const MIN_SPAWN_DISTANCE := 220.0

@onready var player: CharacterBody2D = $PlayerCombat
@onready var background: Node2D = $Background
@onready var dash_bar_fill: ColorRect = $UI/DashBarBack/DashBarFill
@onready var mob_label: Label = $UI/MobLabel
@onready var active_label: Label = $UI/ActiveLabel
@onready var item_message_label: Label = $UI/ItemMessageLabel

var is_boss_fight := false
var had_elite := false
const ELITE_LOOT_BONUS := 0.2
var combat_over := false
var hearts := Hearts.new()
var message_serial := 0
var waiting_to_leave := false
var leaving := false

func _ready() -> void:
	player.died.connect(_on_player_died)
	player.item_message.connect(_on_item_message)
	hearts.position = Vector2(10, 8)
	# Rappel des touches au debut du combat, puis il s'efface pour ne pas cacher les ennemis.
	$UI/Instructions.text = Controls.help(["move", "attack", "dash", "active", "interact", "inventory"])
	$UI/Instructions.create_tween().tween_property($UI/Instructions, "modulate:a", 0.0, 1.0).set_delay(4.0)
	$UI.add_child(hearts)
	$UI.add_child(InventoryPanel.new())
	$UI.add_child(SpeedrunTimer.new())

	var floor_meta := GameState.current_floor()
	DreamTheme.set_family(floor_meta["family"])
	var night: String = GameState.tower()["id"]
	background.setup(floor_meta["family"], floor_meta["intensity"], night)
	var ambient := CanvasModulate.new()
	# Arene moins sombre que l'exploration : les telegraphes doivent rester lisibles.
	ambient.color = DreamTheme.ambient_color(floor_meta["family"], floor_meta["intensity"], night).lerp(Color.WHITE, 0.7)
	add_child(ambient)
	player.add_child(DreamTheme.make_ambient_particles(floor_meta["family"], night))

	GameState.start_combat()
	var mobs := _pick_mobs()
	is_boss_fight = GameState.guardian_fight or mobs.any(func(m): return m.is_boss)
	Sound.music("boss" if is_boss_fight else "combat")
	if is_boss_fight:
		Sound.play("boss")
	for mob in mobs:
		_spawn_mob(mob)

# Ennemis du combat (pas encore dans l'arbre), tires du bestiaire de la nuit (scripts/combat/bestiary.gd).
func _pick_mobs() -> Array:
	var night: String = GameState.tower()["id"]
	var nightmare_floor: bool = GameState.current_floor()["intensity"] == FloorGenerator.Intensity.CAUCHEMAR
	if GameState.guardian_fight:
		if GameState.is_last_floor() and not GameState.guardian_exit_down:
			return [Bestiary.final_boss(night)]
		return [Bestiary.boss(night, nightmare_floor, GameState.boss_history)]
	if GameState.floor_index < 0 and randf() < NEGATIVE_BOSS_CHANCE:
		return [Bestiary.boss(night, nightmare_floor, GameState.boss_history)]
	var mobs := []
	for i in _encounter_size():
		mobs.append(Bestiary.creature(night, nightmare_floor))
	return mobs

func _encounter_size() -> int:
	return mini(MAX_MOBS, 2 + abs(GameState.floor_index) / FLOORS_PER_EXTRA_MOB + randi() % 2)

func _spawn_mob(mob: BaseMob) -> void:
	mob.position = Vector2(450, 140) if mob.is_boss else _random_spawn_position()
	add_child(mob)
	mob.telegraph_duration *= 1.0 + GameState.mod("telegraph")
	mob.apply_difficulty(GameState.difficulty())
	mob.apply_variant()
	had_elite = had_elite or mob.elite
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
	hearts.max_hp = player.max_hp
	hearts.hp = player.hp

	var dash_ratio: float = 1.0 - clampf(player.dash_cooldown_timer / player.dash_cooldown_effective, 0.0, 1.0)
	dash_bar_fill.size.x = dash_bar_fill.get_parent().size.x * dash_ratio

	active_label.text = "%s\nPassifs : %d  (%s)" % [GameState.active_summary(), GameState.passive_count(), Controls.name_of("inventory")]

	if combat_over:
		return
	var alive := _alive_mobs()
	if alive.is_empty():
		_on_victory()
	elif is_boss_fight:
		var boss: BaseMob = alive.filter(func(m): return m.is_boss).front() if alive.any(func(m): return m.is_boss) else alive[0]
		var boss_name: String = boss.display_name if boss.display_name != "" else "Gardien du portail"
		mob_label.text = "%s  PV %d" % [boss_name, boss.hp]
	else:
		mob_label.text = "Ennemis : %d" % alive.size()

# Apres la victoire, Entree / Start (ou A loin de l'objet) : continuer. Pendant le combat, menu = fuir.
func _unhandled_input(event: InputEvent) -> void:
	if waiting_to_leave and (event.is_action_pressed("ui_accept") or event.is_action_pressed("pause")):
		_leave()
	elif event.is_action_pressed("pause") and not combat_over:
		GameState.end_combat()
		GameState.guardian_fight = false
		SceneTransition.change_scene(GameState.return_map_path)

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
	GameState.end_combat()
	Sound.play("victory")
	combat_over = true
	player.invincible = true
	GameState.hp_lost = player.max_hp - player.hp  # les PV perdus le restent jusqu'aux etoiles
	if not GameState.guardian_fight:
		GameState.current_floor()["wins"] += 1
	GameState.coins += GameState.COINS_PER_GUARDIAN if GameState.guardian_fight else GameState.COINS_PER_WIN
	GameState.recharge_active()
	mob_label.text = "Gardien vaincu !" if GameState.guardian_fight else "Victoire !"
	if is_boss_fight or had_elite or randf() < DROP_CHANCE + GameState.mod("drop_chance"):
		_drop_item()
		return
	await get_tree().create_timer(1.4).timeout
	_leave()

# Le butin tombe au sol : on choisit de le prendre (interagir) ou de garder son objet (continuer).
func _drop_item() -> void:
	var pickup := ItemPickup.new()
	var bonus := GameState.BOSS_LOOT_BONUS if is_boss_fight else (ELITE_LOOT_BONUS if had_elite else 0.0)
	pickup.item_id = GameState.roll_item_id(bonus)
	pickup.position = player.position + Vector2(0, -80 if player.position.y > 150 else 80)
	add_child(pickup)
	pickup.taken.connect(_on_pickup_taken)
	waiting_to_leave = true
	var go_on := "Start" if Controls.using_gamepad else "Entrée"
	_on_item_message("%s : prendre l'objet   |   %s : continuer" % [Controls.name_of("interact"), go_on], 0.0)

func _on_pickup_taken(_pickup: ItemPickup, taken_id: String, old_id: String) -> void:
	Sound.play("pickup")
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
	mob_label.text = "Vaincu..."
	await get_tree().create_timer(1.0).timeout
	GameState.apply_combat_death()
	SceneTransition.change_scene(GameState.MENU_PATH)
