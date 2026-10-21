extends Node

# Jeudi (Frustration) - Portes closes : des barrieres ferment des couloirs de l'etage. Elles
# s'ouvrent des qu'on a gagne un combat sur l'etage. Premier etage : une seule, sur un detour ;
# a partir de la moitie de la nuit, l'une d'elles barre le chemin du portail (jusqu'a trois).

const INTRO := "Des barrières partout... Rien ne se passe comme prévu."
const BARRIERS := Vector2(1, 3)  # premier etage, dernier
const ON_PATH_FROM := 0.5  # force a partir de laquelle une barriere coupe le chemin du portail
const GateTexture := preload("res://assets/sprites/decor/jeudi/porte_close.png")
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var strength := 0.0
var map: Node
var floor_data
var barriers: Array = []  # cases fermees

func _ready() -> void:
	if GameState.current_floor()["wins"] > 0:
		return  # deja un combat gagne : tout est ouvert
	_place_barriers.call_deferred()  # apres les murs de l'etage

func _place_barriers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.current_floor()["seed"] + 4
	var path := _shortest_path(floor_data.spawn_cell, floor_data.exit_cell)
	var avoid: Array = [floor_data.spawn_cell, floor_data.exit_cell, floor_data.secondary_cell, floor_data.npc_cell] + floor_data.chest_cells
	var corridors: Array = floor_data.floor_cells.keys().filter(func(c): return _is_corridor(c) and c not in avoid)
	corridors.sort()
	var on_path := corridors.filter(func(c): return c in path and (c - floor_data.spawn_cell).length() > 2)
	var detours := corridors.filter(func(c): return c not in path)
	var count := roundi(lerpf(BARRIERS.x, BARRIERS.y, strength))
	if strength >= ON_PATH_FROM and not on_path.is_empty():
		barriers.append(on_path[rng.randi() % on_path.size()])
	while barriers.size() < count and not detours.is_empty():
		barriers.append(detours.pop_at(rng.randi() % detours.size()))
	for cell in barriers:
		_close(cell)

# Couloir : sol des deux cotes sur un axe, mur des deux cotes sur l'autre (on ne peut pas contourner).
func _is_corridor(c: Vector2i) -> bool:
	var cells: Dictionary = floor_data.floor_cells
	var horizontal: bool = cells.has(c + Vector2i.LEFT) and cells.has(c + Vector2i.RIGHT) and not cells.has(c + Vector2i.UP) and not cells.has(c + Vector2i.DOWN)
	var vertical: bool = cells.has(c + Vector2i.UP) and cells.has(c + Vector2i.DOWN) and not cells.has(c + Vector2i.LEFT) and not cells.has(c + Vector2i.RIGHT)
	return horizontal or vertical

func _shortest_path(from: Vector2i, to: Vector2i) -> Array:
	var previous := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for d in DIRS:
			var n: Vector2i = c + d
			if floor_data.floor_cells.has(n) and not previous.has(n):
				previous[n] = c
				queue.append(n)
	var path := []
	var c := to
	while previous.has(c) and c != from:
		path.append(c)
		c = previous[c]
	return path

func _close(cell: Vector2i) -> void:
	var gate := StaticBody2D.new()
	gate.position = map._cell_to_world(cell)
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2.ONE * FloorGenerator.CELL_SIZE
	gate.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = GateTexture
	sprite.scale = Vector2(3, 3)
	gate.add_child(sprite)
	# Zone un peu plus grande que la barriere : explique pourquoi on ne passe pas.
	var notice := Area2D.new()
	var notice_shape := CollisionShape2D.new()
	notice_shape.shape = RectangleShape2D.new()
	notice_shape.shape.size = Vector2.ONE * FloorGenerator.CELL_SIZE * 1.4
	notice.add_child(notice_shape)
	notice.body_entered.connect(func(body):
		if body.is_in_group("player"):
			map._show_message("Fermé. Gagne un combat sur cet étage pour que ça s'ouvre."))
	gate.add_child(notice)
	map.generated_root.add_child(gate)
