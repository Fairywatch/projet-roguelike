extends Node

# Mercredi (Doute) - Faux portails : l'etage contient des portails leurres en plus du vrai. En
# prendre un ramene au depart de l'etage (et le leurre disparait). Les leurres scintillent, le vrai
# reste stable : tres visible au premier etage, presque rien au dernier, ou ils sont trois.

const INTRO := "Plusieurs portails... mais un seul est vrai."
const DECOYS := Vector2(1, 3)  # nombre de leurres : premier etage, dernier
const FLICKER := Vector2(0.55, 0.12)  # amplitude du scintillement
const PortalTexture := preload("res://assets/sprites/props/portal.png")
const COLOR := Color(1, 0.85, 0.45)  # comme le vrai portail (floor_exit.gd)

var strength := 0.0
var map: Node
var floor_data
var decoys: Array = []

func _ready() -> void:
	# Apres le placement de l'etage (le vrai portail doit exister pour garder ses distances).
	_spawn_decoys.call_deferred()

func _spawn_decoys() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.current_floor()["seed"] + 3
	var spawn: Vector2i = floor_data.spawn_cell
	var exit: Vector2i = floor_data.exit_cell
	var cells: Array = floor_data.floor_cells.keys().filter(func(c):
		return c not in [spawn, exit, floor_data.secondary_cell] and (c - spawn).length() > 4 and (c - exit).length() > 3)
	cells.sort()
	for i in roundi(lerpf(DECOYS.x, DECOYS.y, strength)):
		if cells.is_empty():
			return
		var cell: Vector2i = cells.pop_at(rng.randi() % cells.size())
		cells = cells.filter(func(c): return (c - cell).length() > 3)  # leurres espaces
		if cell not in GameState.current_floor().get("used_decoys", []):  # deja demasque
			decoys.append(_make_decoy(cell))

func _make_decoy(cell: Vector2i) -> Area2D:
	var decoy := Area2D.new()
	decoy.position = map._cell_to_world(cell)
	decoy.set_meta("cell", cell)
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 40
	decoy.add_child(shape)
	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = PortalTexture
	visual.modulate = COLOR
	decoy.add_child(visual)
	decoy.add_child(DreamTheme.make_light(COLOR, 120.0, 1.2))
	decoy.body_entered.connect(_on_decoy_entered.bind(decoy))
	map.generated_root.add_child(decoy)
	return decoy

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var amp := lerpf(FLICKER.x, FLICKER.y, strength)
	for decoy in decoys:
		if not is_instance_valid(decoy):
			continue
		var visual: Sprite2D = decoy.get_node("Visual")
		# Meme mouvement que le vrai portail, plus un scintillement irregulier.
		visual.rotation = t * 1.5
		visual.scale = Vector2.ONE * 2.0 * (1.0 + sin(t * 3.0) * 0.08)
		visual.modulate.a = 1.0 - amp * (0.5 + 0.5 * sin(t * 17.0 + decoy.position.x)) * float(sin(t * 5.3 + decoy.position.y) > 0.2)

func _on_decoy_entered(body: Node2D, decoy: Area2D) -> void:
	if not body.is_in_group("player") or body.frozen:
		return
	Sound.play("portal")
	Fx.puff(map.generated_root, decoy.global_position, COLOR, 14)
	decoy.queue_free()
	decoys.erase(decoy)
	var floor_meta: Dictionary = GameState.current_floor()
	floor_meta["used_decoys"] = floor_meta.get("used_decoys", []) + [decoy.get_meta("cell")]
	body.global_position = map._cell_to_world(floor_data.spawn_cell)
	body.reset_physics_interpolation()
	map._show_message("Ce n'était qu'un reflet... Te revoilà au début de l'étage.")
