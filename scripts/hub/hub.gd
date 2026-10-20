extends Node2D

# Hub de la semaine : le reveur marche jusqu'a la tour de la nuit qu'il veut jouer.
# Une nuit n'est ouverte qu'une fois celle de la veille terminee. On y trouve aussi la
# Marchande de lune (boutique) et l'horloge qui active le mode speedrun.

const AREA := Vector2(1400, 540)
const TOWER_Y := 250.0  # pied des tours
const TOWER_X0 := 190.0
const TOWER_STEP := 170.0
const SPAWN := Vector2(700, 440)
const MERCHANT_POS := Vector2(90, 430)
const CLOCK_POS := Vector2(1310, 430)
const BOOK_POS := Vector2(540, 480)
const TRIGGER_RADIUS := 56.0
const PadlockTexture := preload("res://assets/sprites/hub/padlock.png")
const StarTexture := preload("res://assets/sprites/decor/paradoxal/etoile.png")
const MerchantTexture := preload("res://assets/sprites/npcs/marchande.png")
const ClockTexture := preload("res://assets/sprites/decor/paradoxal/horloge.png")
const BookTexture := preload("res://assets/sprites/hub/book.png")

# Choix du mode speedrun, garde tant que le jeu tourne.
static var speedrun_choice := false

@onready var player: CharacterBody2D = $Player
@onready var background: Node2D = $Background
@onready var prompt_label: Label = $UI/Prompt
@onready var status_label: Label = $UI/Status

var near := ""  # "tower_3", "shop", "clock" ou ""
var confirm_abandon := -1
var panel_open := false

func _ready() -> void:
	DreamTheme.set_family(FloorGenerator.Family.PROFOND)
	background.area = AREA
	background.setup(FloorGenerator.Family.PARADOXAL, FloorGenerator.Intensity.REVE)
	var ambient := CanvasModulate.new()
	ambient.color = Color(0.55, 0.5, 0.75)
	add_child(ambient)
	_build_walls()
	for i in Towers.LIST.size():
		_build_tower(i)
	_add_spot("shop", MERCHANT_POS, MerchantTexture, "Marchande de lune", Color(1, 0.9, 0.6))
	_add_spot("clock", CLOCK_POS, ClockTexture, "Horloge du réveil", Color(1, 0.8, 0.4))
	_add_spot("book", BOOK_POS, BookTexture, "Livre des songes", Color(0.7, 0.75, 1))
	player.global_position = SPAWN
	player.reset_physics_interpolation()
	$UI/Hint.text = "Marche jusqu'à la nuit de ton choix  |  " + Controls.help(["interact", "pause"])
	player.add_child(DreamTheme.make_light(Color(1, 0.95, 0.85), 220.0, 0.8))
	player.add_child(DreamTheme.make_ambient_particles(FloorGenerator.Family.PARADOXAL))
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_right = int(AREA.x)
	camera.limit_bottom = int(AREA.y)
	Sound.music("reve")
	_refresh_ui()

func _build_walls() -> void:
	for rect in [Rect2(-40, -40, AREA.x + 80, 40), Rect2(-40, AREA.y, AREA.x + 80, 40),
			Rect2(-40, 0, 40, AREA.y), Rect2(AREA.x, 0, 40, AREA.y)]:
		_add_solid(rect)

func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	body.position = rect.get_center()
	body.add_child(shape)
	add_child(body)

func tower_state(i: int) -> String:
	if i >= GameState.unlocked_towers:
		return "locked"
	return "done" if Towers.LIST[i]["id"] in GameState.completed_towers else "open"

func _build_tower(i: int) -> void:
	var tower: Dictionary = Towers.LIST[i]
	var x := TOWER_X0 + i * TOWER_STEP
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/hub/tower_%s.png" % tower["id"])
	sprite.scale = Vector2(2, 2)
	sprite.centered = false
	sprite.position = Vector2(x - sprite.texture.get_width(), TOWER_Y - sprite.texture.get_height() * 2)
	add_child(sprite)
	_add_solid(Rect2(x - 22, TOWER_Y - 40, 44, 34))  # le corps de la tour bloque le passage
	var state := tower_state(i)
	if state == "locked":
		sprite.modulate = Color(0.35, 0.33, 0.42)
		_add_icon(PadlockTexture, Vector2(x, TOWER_Y - 20))
	else:
		var light := DreamTheme.make_light(Color(1, 0.85, 0.55).lerp(Color(1, 0.3, 0.3), float(i) / 6.0), 110.0, 0.9)
		light.position = Vector2(x, TOWER_Y - 40)
		add_child(light)
	if state == "done":
		_add_icon(StarTexture, Vector2(x, sprite.position.y - 16))
	var name_label := _world_label(Towers.title(i), Vector2(x, TOWER_Y + 8), 10)
	name_label.modulate = Color(1, 1, 1) if state != "locked" else Color(0.6, 0.6, 0.7)
	_add_trigger("tower_%d" % i, Vector2(x, TOWER_Y + 10))

func _add_spot(id: String, pos: Vector2, texture: Texture2D, title: String, glow: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(2, 2)
	sprite.position = pos
	add_child(sprite)
	var light := DreamTheme.make_light(glow, 80.0, 0.9)
	light.position = pos
	add_child(light)
	_world_label(title, pos + Vector2(0, 22), 9)
	_add_trigger(id, pos)

func _add_icon(texture: Texture2D, pos: Vector2) -> void:
	var icon := Sprite2D.new()
	icon.texture = texture
	icon.scale = Vector2(2, 2)
	icon.position = pos
	add_child(icon)

func _world_label(text: String, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 16)
	label.position = pos - Vector2(80, 0)
	add_child(label)
	return label

func _add_trigger(id: String, pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = TRIGGER_RADIUS
	area.add_child(shape)
	area.body_entered.connect(func(body): if body.is_in_group("player"): _set_near(id))
	area.body_exited.connect(func(body): if body.is_in_group("player") and near == id: _set_near(""))
	add_child(area)

func _set_near(id: String) -> void:
	near = id
	confirm_abandon = -1
	_refresh_ui()

func _refresh_ui() -> void:
	status_label.text = "Pièces : %d\nSpeedrun : %s" % [GameState.coins, "oui" if speedrun_choice else "non"]
	prompt_label.visible = near != ""
	if near == "shop":
		prompt_label.text = "%s : ouvrir la boutique" % Controls.name_of("interact")
	elif near == "book":
		prompt_label.text = "%s : relire l'histoire du rêveur" % Controls.name_of("interact")
	elif near == "clock":
		prompt_label.text = "%s : %s le mode speedrun (le réveil sonne à la fin du chrono)" % [Controls.name_of("interact"), "désactiver" if speedrun_choice else "activer"]
	elif near.begins_with("tower_"):
		prompt_label.text = _tower_prompt(near.trim_prefix("tower_").to_int())

func _tower_prompt(i: int) -> String:
	var tower: Dictionary = Towers.LIST[i]
	var head := "%s  (%d étages)\n%s" % [Towers.title(i), tower["floors"], tower["desc"]]
	if tower_state(i) == "locked":
		return head + "\nVerrouillée : termine d'abord la nuit de %s." % Towers.LIST[i - 1]["name"]
	if GameState.best_times.has(tower["id"]):
		head += "  Record speedrun : %s" % GameState.format_time(GameState.best_times[tower["id"]])
	if GameState.run_started and GameState.tower_index == i:
		return head + "\n%s : reprendre la nuit (étage %d)" % [Controls.name_of("interact"), GameState.floor_index]
	if GameState.run_started and confirm_abandon == i:
		return head + "\n%s à nouveau : abandonner la nuit de %s en cours" % [Controls.name_of("interact"), GameState.tower()["name"]]
	return head + "\n%s : entrer" % Controls.name_of("interact") + ("  (speedrun)" if speedrun_choice else "")

func _unhandled_input(event: InputEvent) -> void:
	if panel_open:
		return
	if event.is_action_pressed("pause"):
		player.frozen = true
		SceneTransition.change_scene(GameState.MENU_PATH)
	elif event.is_action_pressed("interact") and near != "":
		interact()

func interact() -> void:
	if near == "shop":
		_open_shop()
	elif near == "book":
		player.frozen = true
		GameState.play_cutscene("intro", GameState.HUB_PATH)
	elif near == "clock":
		speedrun_choice = not speedrun_choice
		Sound.play("ui_select")
		_refresh_ui()
	elif near.begins_with("tower_"):
		_enter_tower(near.trim_prefix("tower_").to_int())

func _enter_tower(i: int) -> void:
	if tower_state(i) == "locked":
		Sound.play("ui_select")
		return
	if GameState.run_started and GameState.tower_index == i:
		_go()
		return
	if GameState.run_started and confirm_abandon != i:
		confirm_abandon = i
		_refresh_ui()
		return
	GameState.new_run(i, speedrun_choice)
	_go()

func _go() -> void:
	player.frozen = true
	Sound.play("portal")
	SceneTransition.change_scene(GameState.return_map_path, SceneTransition.Style.SOFT)

func _open_shop() -> void:
	panel_open = true
	player.frozen = true
	var panel := ShopPanel.new()
	panel.closed.connect(func():
		panel_open = false
		player.frozen = false
		_refresh_ui())
	$UI.add_child(panel)
