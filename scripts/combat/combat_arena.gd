extends Node2D

const DROP_CHANCE := 0.45
const MAX_MOBS := 4
const FLOORS_PER_EXTRA_MOB := 4
const NORMAL_MAX_MOBS := 3  # mode Normal : un ennemi de moins, jamais plus de 3
const NORMAL_BOSS_HP := 0.8  # mode Normal : boss moins resistants...
const NORMAL_BOSS_COOLDOWN := 1.15  # ... et qui attaquent un peu moins souvent
const MIN_ENEMY_HP_MULT := 0.5  # les passifs n'enlevent jamais plus de la moitie des PV ennemis
const NEGATIVE_BOSS_CHANCE := 1.0 / 7.0
const ARENA_SIZE := Vector2(900, 540)
const SPAWN_MARGIN := 60.0
const MIN_SPAWN_DISTANCE := 220.0

@onready var player: CharacterBody2D = $PlayerCombat
@onready var background: Node2D = $Background
var hud := GameHud.make(true)
var counter := PanelContainer.new()  # ennemis restants, en haut au centre
var mob_label := Label.new()

var is_boss_fight := false
var picked_boss := false  # _pick_mobs a tire un boss (ils ne se declarent boss qu'une fois dans l'arbre)
const AMBUSH_STUN := 1.6
var had_elite := false
const ELITE_LOOT_BONUS := 0.2
var combat_over := false
var boss_bar := BossBar.new()
var extra_mobs := 0  # ennemis en plus (regle du samedi)
var shown_hp := -1
var waiting_to_leave := false
const FLEE_CONFIRM_TIME := 2.5  # secondes pour confirmer une fuite d'un deuxieme appui
var flee_asked_at := -100.0
var leaving := false

func _ready() -> void:
	player.died.connect(_on_player_died)
	player.item_message.connect(_on_item_message)
	player.hp_changed.connect(_on_player_hp_changed)
	# Rappel des touches au debut du combat, puis il s'efface pour ne pas cacher les ennemis.
	_refresh_hints()
	GameState.input_device_changed.connect(_refresh_hints)
	$UI/Instructions.create_tween().tween_property($UI/Instructions, "modulate:a", 0.0, 1.0).set_delay(4.0)
	hud.toast.at_top = true
	$UI.add_child(OffscreenMarkers.new())
	$UI.add_child(hud)
	_build_counter()
	boss_bar.position = Vector2(roundf((640 - BossBar.SIZE.x) / 2.0), 16)  # le scotch du papier reste visible
	boss_bar.visible = false
	$UI.add_child(boss_bar)
	hud.see_through.append_array([counter, boss_bar])
	$UI.add_child(InventoryPanel.new())
	$UI.add_child(SpeedrunTimer.new())

	var floor_meta := GameState.current_floor()
	DreamTheme.set_family(floor_meta["family"])
	var night: String = GameState.night()
	background.veiled = true
	background.setup(floor_meta["family"], floor_meta["intensity"], night)
	var ambient := CanvasModulate.new()
	# Arene moins sombre que l'exploration : les telegraphes doivent rester lisibles.
	ambient.color = DreamTheme.ambient_color(floor_meta["family"], floor_meta["intensity"], night).lerp(Color.WHITE, 0.7)
	add_child(ambient)
	player.add_child(DreamTheme.make_ambient_particles(floor_meta["family"], night))

	var rule_script := Places.rule_script(night)
	if rule_script and "apply_combat" in rule_script.get_script_method_list().map(func(m): return m["name"]):
		rule_script.apply_combat(self, rule_strength())

	GameState.start_combat()
	var lesson := GameState.needs_tutorial()  # tout premier combat : un seul ennemi, d'entrainement
	var mobs: Array = [Bestiary.make("lundi/mouton")] if lesson else _pick_mobs()
	is_boss_fight = picked_boss
	Sound.music("boss" if is_boss_fight else "combat")
	if is_boss_fight:
		Sound.play("boss")
	for mob in mobs:
		_spawn_mob(mob)
	if GameState.ambush and not lesson:
		for mob in mobs:
			mob.stun(AMBUSH_STUN)
		# Ceux qui arrivent juste apres (agneaux du Mouton insomniaque...) sont pris de court aussi.
		_stun_newcomers.call_deferred()
		_on_item_message("Embuscade ! Les cauchemars sont pris de court.", 2.5)
	GameState.ambush = false
	GameState.encounter_lead = ""
	if lesson:
		mobs[0].position = player.position + Vector2(170, 0)
		var tutorial := Tutorial.new()
		tutorial.player = player
		tutorial.dummy = mobs[0]
		$UI.add_child(tutorial)
		$UI/Instructions.visible = false

# Ennemis restants : un crane et leur nombre, dans une bulle en haut au centre.
func _stun_newcomers() -> void:
	for mob in _alive_mobs():
		if mob.state == BaseMob.State.CHASE:
			mob.stun(AMBUSH_STUN)

func _build_counter() -> void:
	Paper.apply(counter)
	counter.theme_type_variation = &"HudPanel"
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.set_anchors_preset(Control.PRESET_CENTER_TOP)
	counter.grow_horizontal = Control.GROW_DIRECTION_BOTH
	counter.offset_top = 6
	counter.offset_bottom = 6
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.add_child(HudIcon.make("skull"))
	mob_label.add_theme_font_size_override("font_size", 15)
	row.add_child(mob_label)
	counter.add_child(row)
	$UI.add_child(counter)

func _on_player_hp_changed(hp: int) -> void:
	if shown_hp >= 0 and hp < shown_hp:
		hud.flash_hurt()
	shown_hp = hp

# Ennemis du combat (pas encore dans l'arbre), tires du bestiaire de la nuit (scripts/combat/bestiary.gd).
func _pick_mobs() -> Array:
	var night: String = GameState.mob_night()
	var nightmare_floor: bool = GameState.current_floor()["intensity"] == FloorGenerator.Intensity.CAUCHEMAR
	if GameState.guardian_fight:
		if (GameState.is_last_floor() and not GameState.guardian_exit_down) or GameState.endless_final_guardian():
			picked_boss = true
			return [Bestiary.final_boss(night)]
		if GameState.floor_has_boss():
			picked_boss = true
			return [Bestiary.boss(night, nightmare_floor, GameState.boss_history)]
	elif GameState.floor_index < 0 and randf() < NEGATIVE_BOSS_CHANCE:
		picked_boss = true
		return [Bestiary.boss(night, nightmare_floor, GameState.boss_history)]
	var mobs := []
	for i in _encounter_size() + extra_mobs + int(GameState.mod("enemy_count")):
		mobs.append(Bestiary.creature(night, nightmare_floor))
	# Le cauchemar errant touche sur la carte mene le combat.
	if GameState.encounter_lead != "" and not mobs.is_empty():
		mobs[0] = Bestiary.creature(night, nightmare_floor, GameState.encounter_lead)
	# Gardien sans boss : une meute menee par une elite.
	if GameState.guardian_fight:
		mobs[0].elite = true
	return mobs

# Meme progression que la regle sur la carte : 0 au premier etage, 1 au dernier.
func rule_strength() -> float:
	return GameState.night_progress()

func _encounter_size() -> int:
	var size := mini(MAX_MOBS, 2 + abs(GameState.floor_index) / FLOORS_PER_EXTRA_MOB + randi() % 2)
	return size if GameState.nightmare_mode else clampi(size - 1, 1, NORMAL_MAX_MOBS)

func _spawn_mob(mob: BaseMob) -> void:
	mob.position = Vector2(450, 140) if mob.is_boss else _random_spawn_position()
	add_child(mob)
	mob.telegraph_duration *= 1.0 + GameState.mod("telegraph")
	mob.apply_difficulty(GameState.difficulty())
	mob.apply_variant()
	had_elite = had_elite or mob.elite
	# Passifs qui affaiblissent les ennemis (Marchand de sable, Montre a gousset...).
	if mob.is_boss and not GameState.nightmare_mode:
		mob.hp = ceili(mob.hp * NORMAL_BOSS_HP)
		mob.cooldown_duration *= NORMAL_BOSS_COOLDOWN
	mob.hp = maxi(1, ceili(mob.hp * maxf(MIN_ENEMY_HP_MULT, 1.0 + GameState.mod("enemy_hp"))))
	mob.max_hp = mob.hp
	mob.chase_speed *= maxf(0.3, 1.0 + GameState.mod("enemy_speed"))
	mob.cooldown_duration *= maxf(0.3, 1.0 + GameState.mod("enemy_cooldown"))
	mob.died.connect(player.on_enemy_killed)
	mob.died.connect(GameState.note.bind("kills"))

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
	hud.set_health(player.hp, player.max_hp)
	if shown_hp < 0:
		shown_hp = player.hp
	hud.set_dash(1.0 - clampf(player.dash_cooldown_timer / player.dash_cooldown_effective, 0.0, 1.0))
	hud.set_special(1.0 - clampf(player.special_timer / player.special_cooldown_effective, 0.0, 1.0))
	hud.sync()

	if combat_over:
		return
	var alive := _alive_mobs()
	if alive.is_empty():
		_on_victory()
	elif is_boss_fight:
		var boss: BaseMob = alive.filter(func(m): return m.is_boss).front() if alive.any(func(m): return m.is_boss) else alive[0]
		counter.visible = false
		boss_bar.visible = true
		boss_bar.show_boss(boss)
	else:
		mob_label.text = "%d" % alive.size()

# Apres la victoire, Entree / Start (ou A loin de l'objet) : continuer. Pendant le combat, menu = fuir.
func _unhandled_input(event: InputEvent) -> void:
	if waiting_to_leave and (event.is_action_pressed("ui_accept") or event.is_action_pressed("pause")):
		_leave()
	elif event.is_action_pressed("pause") and not combat_over:
		_try_flee()

# Fuite : jamais devant un gardien ou un boss. Ailleurs, elle se confirme d'un deuxieme appui, coute
# des pieces, et les PV perdus pendant le combat le restent (sinon fuir soignait).
func _try_flee() -> void:
	if is_boss_fight or GameState.guardian_fight:
		_on_item_message("Impossible de fuir un gardien !")
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - flee_asked_at > FLEE_CONFIRM_TIME:
		flee_asked_at = now
		var cost := mini(GameState.FLEE_COST, GameState.coins)
		_on_item_message("%s encore pour fuir (-%d pièce%s, les PV perdus le restent)" % [Controls.name_of("pause"), cost, "s" if cost > 1 else ""], FLEE_CONFIRM_TIME)
		return
	combat_over = true
	GameState.end_combat()
	GameState.hp_lost = player.max_hp - player.hp
	GameState.coins = maxi(0, GameState.coins - GameState.FLEE_COST)
	GameState.note("fled")
	GameState.pending_message = "Tu as fui le combat..."
	SceneTransition.change_scene(GameState.return_map_path)

# duration <= 0 : le message reste affiche.
func _on_item_message(text: String, duration: float = 2.0) -> void:
	hud.say(text, duration)

func _on_victory() -> void:
	GameState.end_combat()
	Sound.play("victory")
	combat_over = true
	boss_bar.visible = false
	player.invincible = true
	GameState.hp_lost = player.max_hp - player.hp  # les PV perdus le restent jusqu'aux etoiles
	GameState.note("wins")
	if not GameState.guardian_fight:
		GameState.current_floor()["wins"] += 1
	GameState.coins += GameState.COINS_PER_GUARDIAN if GameState.guardian_fight else GameState.COINS_PER_WIN
	GameState.recharge_active()
	counter.visible = false
	TitleBanner.show_text($UI, "Gardien vaincu !" if GameState.guardian_fight else "Victoire !", Color(1, 0.88, 0.45))
	# Gardiens et boss : butin garanti. Combats ordinaires : au plus quelques objets par etage.
	var dropped := false
	if is_boss_fight or GameState.guardian_fight:  # gardiens (boss ou meute) : butin garanti
		dropped = _drop_item()
	elif GameState.combat_items_left() <= 0:
		_on_item_message("Plus de butin sur cet étage")
	elif had_elite or randf() < DROP_CHANCE + GameState.mod("drop_chance"):
		dropped = _drop_item()
		if dropped:
			GameState.current_floor()["combat_items"] += 1
	if dropped:
		return
	await get_tree().create_timer(1.4, false).timeout
	_leave()

# Le butin tombe au sol : on choisit de le prendre (interagir) ou de garder son objet (continuer).
# Faux si rien ne tombe (malediction "Poches trouees").
func _drop_item() -> bool:
	var bonus := GameState.BOSS_LOOT_BONUS if is_boss_fight else (ELITE_LOOT_BONUS if had_elite else 0.0)
	var drop := GameState.roll_drop(bonus)
	if drop.is_empty():
		_on_item_message("Poches trouées : rien à ramasser...")
		return false
	var pickup := ItemPickup.new()
	pickup.item_id = drop["id"]
	pickup.mystery = drop["hidden"]
	pickup.position = player.position + Vector2(0, -80 if player.position.y > 150 else 80)
	add_child(pickup)
	pickup.taken.connect(_on_pickup_taken)
	waiting_to_leave = true
	_on_item_message(_leave_text(), 0.0)
	return true

func _leave_text() -> String:
	var go_on := Controls.name_of("pause") if Controls.using_gamepad else "Entrée"
	return "%s : prendre l'objet   |   %s : continuer" % [Controls.name_of("interact"), go_on]

# Aides : reecrites quand on passe du clavier a la manette.
func _refresh_hints() -> void:
	$UI/Instructions.text = Controls.help(["move", "attack", "dash", "special", "active", "interact", "inventory"])
	if waiting_to_leave and not leaving:
		_on_item_message(_leave_text(), 0.0)

func _on_pickup_taken(_pickup: ItemPickup, taken_id: String, old_id: String) -> void:
	Sound.play("pickup")
	player.apply_items()
	var text := "Tu prends %s" % Items.find(taken_id)["name"]
	if old_id != "":
		text += " (tu laisses %s)" % Items.find(old_id)["name"]
	_on_item_message(text, 0.0)
	await get_tree().create_timer(1.0, false).timeout
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
	counter.visible = false
	boss_bar.visible = false
	TitleBanner.show_text($UI, "Vaincu...", Color(1, 0.45, 0.5))
	await get_tree().create_timer(1.0, false).timeout
	GameState.apply_combat_death()
	SceneTransition.change_scene(GameState.MENU_PATH)
