extends Node

# Samedi (Solitude) - Personne : les etages se vident au fil de la nuit (moins de decors, plus de
# PNJ de quete), des silhouettes au loin s'effacent quand on s'approche, et les rencontres sont
# plus rares mais peuvent amener un ennemi de plus : la solitude, puis la foule.

const INTRO := "Il n'y a personne... Juste des silhouettes, au loin."
const SilhouetteTexture := preload("res://assets/sprites/mobs/samedi/silhouette.png")
const SILHOUETTES := Vector2(2, 5)  # premier etage, dernier
const VANISH_DISTANCE := 170.0
const FEWER_DECOR := 0.6  # jusqu'a 60 % de decors en moins
const FEWER_ENCOUNTERS := 0.5  # jusqu'a deux fois moins de rencontres

var strength := 0.0
var map: Node
var floor_data
var silhouettes: Array = []

static func apply_combat(arena: Node, force: float) -> void:
	if randf() < force:
		arena.extra_mobs = 1

func _ready() -> void:
	# Avant le placement de l'etage : moins de decors, plus de PNJ au dernier etage.
	map.decor_factor = 1.0 - FEWER_DECOR * strength
	map.npc_factor = 1.0 - strength
	map.encounter_chance *= 1.0 - FEWER_ENCOUNTERS * strength
	_spawn_silhouettes.call_deferred()

func _spawn_silhouettes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.current_floor()["seed"] + 5
	var cells: Array = floor_data.floor_cells.keys().filter(func(c): return (c - floor_data.spawn_cell).length() > 3)
	cells.sort()
	for i in roundi(lerpf(SILHOUETTES.x, SILHOUETTES.y, strength)):
		if cells.is_empty():
			return
		var figure := Sprite2D.new()
		figure.texture = SilhouetteTexture
		figure.hframes = 2
		figure.scale = Vector2(2, 2)
		figure.modulate = Color(0.15, 0.15, 0.25, 0.55)
		figure.position = map._cell_to_world(cells.pop_at(rng.randi() % cells.size()))
		map.generated_root.add_child(figure)
		silhouettes.append(figure)

func _process(_delta: float) -> void:
	for figure: Sprite2D in silhouettes.duplicate():
		if figure.global_position.distance_to(map.player.global_position) < VANISH_DISTANCE:
			silhouettes.erase(figure)
			var tween := figure.create_tween()
			tween.tween_property(figure, "modulate:a", 0.0, 0.8)
			tween.tween_callback(figure.queue_free)
