extends Node2D

const ENCOUNTER_CHANCE_PARADOXAL := 0.04
const ENCOUNTER_CHANCE_PROFOND := 0.07
const FAMILY_NAMES := ["Sommeil paradoxal", "Sommeil profond"]
const DECOR_CHANCE := 0.16
const DECOR_OFFSET := 30.0
const PLAYER_LIGHT_RADIUS := 260.0
const MESSAGE_DURATION := 4.0
# Effets des decors (voir _on_decor_touched).
const CONSUMABLE_DECOR := ["etoile", "lune", "horloge", "bulle", "champignon", "cristal"]
const GUIDE_DURATION := 10.0
const CLOCK_PAUSE := 15.0
const CRYSTAL_ITEM_CHANCE := 0.3
# Chance qu'un PNJ habite l'etage : le sommeil paradoxal est plus peuple (GDD).
const NPC_CHANCE := {FloorGenerator.Family.PARADOXAL: 0.85, FloorGenerator.Family.PROFOND: 0.35}
const QuestItemTexture := preload("res://assets/sprites/props/quest_item.png")
const FloorExitScene := preload("res://scenes/exploration/FloorExit.tscn")
const ChestScene := preload("res://scenes/exploration/Chest.tscn")

@onready var player: CharacterBody2D = $Player
@onready var flash: ColorRect = $UI/ScreenFlash
@onready var background: Node2D = $Background
@onready var generated_root: Node2D = $Generated
@onready var encounter_timer: Timer = $EncounterTimer
@onready var floor_label: Label = $UI/FloorLabel
@onready var message_label: Label = $UI/MessageLabel
@onready var items_label: Label = $UI/ItemsLabel

var encounter_chance := ENCOUNTER_CHANCE_PARADOXAL
var message_serial := 0
var exit_position := Vector2.ZERO
var guide_timer := 0.0
var encounter_pause := 0.0
var guide_arrow := Polygon2D.new()
var hearts := Hearts.new()

func _ready() -> void:
	var floor_meta := GameState.current_floor()
	DreamTheme.set_family(floor_meta["family"])

	var rng := RandomNumberGenerator.new()
	rng.seed = floor_meta["seed"]
	var size_ratio := float(abs(GameState.floor_index)) / (GameState.floor_count() - 1)
	var floor_data := FloorGenerator.generate(floor_meta["family"], floor_meta["intensity"], rng, size_ratio)

	_build_walls(floor_data)
	background.setup(floor_data.floor_cells, floor_data.size, floor_meta["family"], floor_meta["intensity"], floor_meta["seed"])
	_spawn_floor_exit(floor_data)
	_spawn_chests(floor_data)
	_spawn_npc(floor_data, floor_meta)
	_spawn_decor(floor_data, floor_meta["seed"])
	_setup_ambience(floor_data)
	floor_label.text = "%s  -  Etage %d / %d\n%s" % [GameState.tower()["name"], GameState.floor_index, GameState.floor_count() - 1, FAMILY_NAMES[floor_meta["family"]]]
	encounter_chance = ENCOUNTER_CHANCE_PROFOND if floor_meta["family"] == FloorGenerator.Family.PROFOND else ENCOUNTER_CHANCE_PARADOXAL
	encounter_chance *= maxf(0.2, 1.0 + GameState.mod("encounter_rate"))
	hearts.position = Vector2(10, 8)
	$UI.add_child(hearts)
	$UI.add_child(InventoryPanel.new())
	$UI.add_child(SpeedrunTimer.new())

	if GameState.return_position != Vector2.ZERO:
		player.global_position = GameState.return_position
	else:
		player.global_position = _cell_to_world(floor_data.spawn_cell)

	if GameState.pending_ground_item != "":
		floor_meta["ground_items"].append({"id": GameState.pending_ground_item, "pos": player.global_position + Vector2(70, 0)})
		GameState.pending_ground_item = ""
	for entry in floor_meta["ground_items"]:
		_spawn_pickup(entry)

	guide_arrow.polygon = PackedVector2Array([Vector2(44, 0), Vector2(32, -7), Vector2(32, 7)])
	guide_arrow.color = Color(1, 0.95, 0.7, 0.9)
	guide_arrow.visible = false
	player.add_child(guide_arrow)

	encounter_timer.timeout.connect(_on_encounter_timer_timeout)
	_refresh_hud()
	GameState.save_run()

	if GameState.pending_message != "":
		_show_message(GameState.pending_message)
		GameState.pending_message = ""

func _notification(what: int) -> void:
	# GameState sauvegarde avant nous (il est plus haut dans l'arbre) : on resauvegarde avec la position.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.return_position = player.global_position
		GameState.save_run()

func _process(delta: float) -> void:
	encounter_pause = max(0.0, encounter_pause - delta)
	guide_timer = max(0.0, guide_timer - delta)
	guide_arrow.visible = guide_timer > 0.0
	guide_arrow.rotation = (exit_position - player.global_position).angle()

func _refresh_hud() -> void:
	hearts.max_hp = GameState.max_hp()
	hearts.hp = GameState.current_hp()
	items_label.text = "%s\nPassifs : %d  (Tab)   Pieces : %d" % [GameState.active_summary(), GameState.passive_count(), GameState.coins]

func _show_message(text: String) -> void:
	message_serial += 1
	var serial := message_serial
	message_label.text = text
	message_label.visible = true
	_refresh_hud()
	await get_tree().create_timer(MESSAGE_DURATION).timeout
	if serial == message_serial:
		message_label.visible = false

func _build_walls(floor_data) -> void:
	var shared_shape := RectangleShape2D.new()
	shared_shape.size = Vector2(FloorGenerator.CELL_SIZE, FloorGenerator.CELL_SIZE)
	for y in floor_data.size.y:
		for x in floor_data.size.x:
			var cell := Vector2i(x, y)
			if not floor_data.floor_cells.has(cell) and _touches_floor(floor_data, cell):
				var wall := StaticBody2D.new()
				var shape := CollisionShape2D.new()
				shape.shape = shared_shape
				wall.add_child(shape)
				wall.position = _cell_to_world(cell)
				generated_root.add_child(wall)

# Seuls les murs au contact du sol ont besoin d'une collision.
func _touches_floor(floor_data, cell: Vector2i) -> bool:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if floor_data.floor_cells.has(cell + dir):
			return true
	return false

func _spawn_floor_exit(floor_data) -> void:
	var exit: Area2D = FloorExitScene.instantiate()
	exit_position = _cell_to_world(floor_data.exit_cell)
	exit.position = exit_position
	generated_root.add_child(exit)

	if GameState.floor_index == 0 and GameState.negative_dive_available:
		var descent: Area2D = FloorExitScene.instantiate()
		descent.force_descend = true
		descent.position = _cell_to_world(floor_data.secondary_cell)
		generated_root.add_child(descent)

# Le dernier coffre de l'etage est scelle : il faut gagner des combats sur l'etage pour l'ouvrir.
func _spawn_chests(floor_data) -> void:
	for i in floor_data.chest_cells.size():
		var chest: Area2D = ChestScene.instantiate()
		chest.chest_id = i
		chest.sealed = i == floor_data.chest_cells.size() - 1
		chest.position = _cell_to_world(floor_data.chest_cells[i])
		chest.message.connect(_show_message)
		chest.item_dropped.connect(_spawn_pickup)
		generated_root.add_child(chest)

func _spawn_npc(floor_data, floor_meta: Dictionary) -> void:
	if floor_data.npc_cell == FloorGenerator.NONE:
		return
	if not floor_meta.has("quest"):
		var rng := RandomNumberGenerator.new()
		rng.seed = floor_meta["seed"] + 2
		floor_meta["quest"] = DreamNpc.make_quest(rng) if rng.randf() < NPC_CHANCE[floor_data.family] else {}
	var quest: Dictionary = floor_meta["quest"]
	if quest.is_empty():
		return
	var npc := DreamNpc.new()
	npc.quest = quest
	npc.position = _cell_to_world(floor_data.npc_cell)
	npc.said.connect(_show_message)
	npc.rewarded.connect(_spawn_pickup)
	generated_root.add_child(npc)
	if quest["kind"] == "objet_perdu" and not quest["carried"] and floor_data.quest_cell != FloorGenerator.NONE:
		_spawn_quest_item(_cell_to_world(floor_data.quest_cell), npc)

# Objet perdu d'une quete : ramassable seulement une fois la quete acceptee.
func _spawn_quest_item(pos: Vector2, npc: DreamNpc) -> void:
	var item := Area2D.new()
	item.position = pos
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 24.0
	item.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = QuestItemTexture
	sprite.scale = Vector2(2, 2)
	item.add_child(sprite)
	item.add_child(DreamTheme.make_light(Color(1, 0.85, 0.4), 70.0, 1.2))
	var tween := sprite.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", -5.0, 0.9)
	tween.tween_property(sprite, "position:y", 0.0, 0.9)
	item.body_entered.connect(func(body):
		if not body.is_in_group("player"):
			return
		if npc.quest["state"] != "active":
			_show_message("Un objet brille ici... quelqu'un l'a peut-etre perdu.")
			return
		npc.quest["carried"] = true
		npc.refresh()
		Sound.play("pickup")
		_show_message("Tu as trouve %s ! Rapporte-la a %s." % [npc.npc["object"], npc.npc["name"]])
		item.queue_free())
	generated_root.add_child(item)

# entry vit dans current_floor()["ground_items"] : l'objet reste au sol entre deux combats.
func _spawn_pickup(entry: Dictionary) -> void:
	var pickup := ItemPickup.new()
	pickup.item_id = entry["id"]
	pickup.charges = entry.get("charges", -1)
	pickup.position = entry["pos"]
	pickup.taken.connect(func(p, taken_id, old_id): _on_ground_item_taken(entry, taken_id, old_id, p.charges))
	generated_root.add_child(pickup)

func _on_ground_item_taken(entry: Dictionary, taken_id: String, old_id: String, old_charges: int) -> void:
	Sound.play("pickup")
	var item := Items.find(taken_id)
	var text := "Tu prends %s (%s)" % [item["name"], item["desc"]]
	if old_id == "":
		GameState.current_floor()["ground_items"].erase(entry)
	else:
		entry["id"] = old_id
		entry["charges"] = old_charges
		text += " et laisses %s au sol" % Items.find(old_id)["name"]
	_show_message(text + ".")

# Decors places a partir de la graine de l'etage pour rester identiques entre deux combats.
func _spawn_decor(floor_data, floor_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_seed + 1
	var reserved: Array = [floor_data.spawn_cell, floor_data.exit_cell, floor_data.secondary_cell, floor_data.npc_cell, floor_data.quest_cell] + floor_data.chest_cells
	var names: Array = DreamTheme.DECOR[floor_data.family]
	var used: Array = GameState.current_floor()["used_decor"]
	var cells: Array = floor_data.floor_cells.keys()
	cells.sort()
	var decor_id := 0
	for cell in cells:
		if cell in reserved or rng.randf() >= DECOR_CHANCE:
			continue
		var decor_name: String = names[rng.randi() % names.size()]
		var offset := Vector2(rng.randf_range(-DECOR_OFFSET, DECOR_OFFSET), rng.randf_range(-DECOR_OFFSET, DECOR_OFFSET)).round()
		decor_id += 1
		if decor_id in used and decor_name in CONSUMABLE_DECOR:
			continue
		var decor := DreamDecor.new()
		decor.decor_name = decor_name
		decor.decor_id = decor_id
		decor.family = floor_data.family
		decor.lit = decor_id in used
		decor.position = _cell_to_world(cell) + offset
		decor.touched.connect(_on_decor_touched)
		generated_root.add_child(decor)

func _on_decor_touched(decor: DreamDecor) -> void:
	match decor.decor_name:
		"etoile":
			if not GameState.heal(1):  # comme un coeur dans Isaac : on la laisse si on est en forme
				_show_message("Tu es deja en pleine forme.")
				return
			_consume(decor, Color(1, 0.9, 0.5), "Etoile filante : +1 PV !")
			_refresh_hud()
		"lune":
			guide_timer = GUIDE_DURATION
			_consume(decor, Color(1, 0.95, 0.8), "La lune t'indique le chemin du portail...")
		"horloge":
			encounter_pause = CLOCK_PAUSE
			_consume(decor, Color(1, 0.8, 0.4), "Le temps se fige : aucune rencontre pendant %d s." % CLOCK_PAUSE)
		"bulle":
			_consume(decor, Color(0.7, 0.9, 1), "")
		"bougie":
			if not decor.lit:
				_mark_used(decor)
				decor.light_up()
		"champignon":
			_consume(decor, Color(0.4, 1, 0.85), "Des spores t'endorment plus profondement...")
			_trigger_encounter()
		"cristal":
			var text := "Le cristal se brise."
			if randf() < CRYSTAL_ITEM_CHANCE:
				var entry := {"id": GameState.roll_item_id(), "pos": decor.position}
				GameState.current_floor()["ground_items"].append(entry)
				_spawn_pickup(entry)
				text = "Le cristal se brise et libere %s !" % Items.find(entry["id"])["name"]
			_consume(decor, Color(0.75, 0.55, 1), text)

func _consume(decor: DreamDecor, color: Color, text: String) -> void:
	Sound.play("pop" if decor.decor_name == "bulle" else "sparkle")
	_mark_used(decor)
	decor.vanish(color)
	if text != "":
		_show_message(text)

func _mark_used(decor: DreamDecor) -> void:
	GameState.current_floor()["used_decor"].append(decor.decor_id)

func _setup_ambience(floor_data) -> void:
	Sound.music("reve" if floor_data.family == FloorGenerator.Family.PARADOXAL else "profond")
	var ambient := CanvasModulate.new()
	ambient.color = DreamTheme.ambient_color(floor_data.family, floor_data.intensity)
	add_child(ambient)
	player.add_child(DreamTheme.make_light(Color(1, 0.95, 0.85), PLAYER_LIGHT_RADIUS, 0.9))
	player.add_child(DreamTheme.make_ambient_particles(floor_data.family))
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_right = floor_data.size.x * FloorGenerator.CELL_SIZE
	camera.limit_bottom = floor_data.size.y * FloorGenerator.CELL_SIZE

# E pres d'un objet au sol est gere par ItemPickup ; sinon on rappelle l'objet actif.
# Echap : retour au menu, la partie continue ou on l'a laissee.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE and not player.frozen:
		player.frozen = true
		GameState.return_position = player.global_position
		SceneTransition.change_scene(GameState.MENU_PATH)
		return
	if event.physical_keycode != Controls.INTERACT:
		return
	if not GameState.has_active_item():
		_show_message("Aucun objet actif. Tab : voir tes objets passifs.")
		return
	var item := Items.find_active(GameState.active_item_id)
	_show_message("%s s'utilise en combat avec E (%d/%d charges)." % [item["name"], GameState.active_charges, GameState.ACTIVE_MAX_CHARGES])

func _cell_to_world(cell: Vector2i) -> Vector2:
	var half := FloorGenerator.CELL_SIZE / 2.0
	return Vector2(cell.x * FloorGenerator.CELL_SIZE + half, cell.y * FloorGenerator.CELL_SIZE + half)

func _on_encounter_timer_timeout() -> void:
	if player.frozen or player.velocity.length() < 10.0 or encounter_pause > 0.0:
		return
	if randf() < encounter_chance:
		_trigger_encounter()

func _trigger_encounter() -> void:
	if player.frozen:
		return
	Sound.play("encounter")
	player.frozen = true
	var tween := create_tween()
	if Settings.enabled("flashes"):
		tween.tween_property(flash, "modulate:a", 1.0, 0.08)
		tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	else:
		tween.tween_interval(0.3)
	await tween.finished
	GameState.return_position = player.global_position
	SceneTransition.change_scene("res://scenes/combat/CombatArena.tscn", SceneTransition.style_for_family(GameState.current_floor()["family"]))
