class_name FloorGenerator
extends RefCounted

enum Family { PARADOXAL, PROFOND }
enum Intensity { REVE, CAUCHEMAR }

# Taille de la grille selon l'avancee dans la tour : petits etages au debut, grands a la fin.
const MIN_GRID := Vector2i(16, 10)
const MAX_GRID := Vector2i(34, 20)
const MIN_ROOMS := 6
const CELL_SIZE := 100
const MAX_ROOM_ATTEMPTS := 400
const CHEST_COUNT := 2
const NONE := Vector2i(-1, -1)

class FloorData:
	var size: Vector2i
	var family: int
	var intensity: int
	var floor_cells: Dictionary = {}
	var spawn_cell: Vector2i = Vector2i.ZERO
	var exit_cell: Vector2i = Vector2i.ZERO
	var secondary_cell: Vector2i = Vector2i.ZERO
	var chest_cells: Array = []
	# PNJ : une salle libre (NONE si l'etage n'en a plus) ; quest_cell = case la plus eloignee du PNJ.
	var npc_cell: Vector2i = NONE
	var quest_cell: Vector2i = NONE

static func generate(family: int, intensity: int, rng: RandomNumberGenerator, size_ratio: float = 1.0) -> FloorData:
	var data := FloorData.new()
	data.family = family
	data.intensity = intensity
	data.size = Vector2i(Vector2(MIN_GRID).lerp(Vector2(MAX_GRID), clampf(size_ratio, 0.0, 1.0)).round())
	var area_ratio := float(data.size.x * data.size.y) / (MAX_GRID.x * MAX_GRID.y)

	var room_count: int
	var room_min: int
	var room_max: int
	var corridor_width: int
	if family == Family.PARADOXAL:
		room_count = rng.randi_range(16, 22)
		room_min = 2
		room_max = 3
		corridor_width = 1
	else:
		room_count = rng.randi_range(9, 13)
		room_min = 3
		room_max = 5
		corridor_width = 2

	room_count = maxi(MIN_ROOMS, roundi(room_count * area_ratio))
	# Les grandes salles du sommeil profond ne tiennent pas dans un petit etage.
	room_max = room_min + roundi((room_max - room_min) * clampf(size_ratio, 0.0, 1.0))

	var rooms: Array = []
	var attempts := 0
	while rooms.size() < room_count and attempts < MAX_ROOM_ATTEMPTS:
		attempts += 1
		var w := rng.randi_range(room_min, room_max)
		var h := rng.randi_range(room_min, room_max)
		var x := rng.randi_range(1, data.size.x - w - 1)
		var y := rng.randi_range(1, data.size.y - h - 1)
		var rect := Rect2i(x, y, w, h)
		if not _overlaps_any(rect, rooms, 1):
			rooms.append(rect)
			for cx in range(rect.position.x, rect.position.x + rect.size.x):
				for cy in range(rect.position.y, rect.position.y + rect.size.y):
					data.floor_cells[Vector2i(cx, cy)] = true

	for i in range(1, rooms.size()):
		var from: Vector2i = rooms[i - 1].position + rooms[i - 1].size / 2
		var to: Vector2i = rooms[i].position + rooms[i].size / 2
		_carve_corridor(data, from, to, corridor_width)

	if rooms.size() > 0:
		data.spawn_cell = rooms[0].position + rooms[0].size / 2
		# Portails : au fond de l'etage (le plus loin du depart en marchant), et jamais sur un
		# passage (on doit pouvoir tout visiter sans les toucher, sinon cles et couloirs bloques).
		data.exit_cell = _portal_cell(data, rooms, data.spawn_cell, [], [data.spawn_cell])
		data.secondary_cell = _portal_cell(data, rooms, data.exit_cell, [data.exit_cell], [data.spawn_cell, data.exit_cell])

		var candidates: Array = []
		for room in rooms:
			var center: Vector2i = room.position + room.size / 2
			if center not in [data.spawn_cell, data.exit_cell, data.secondary_cell]:
				candidates.append(center)
		while data.chest_cells.size() < CHEST_COUNT and not candidates.is_empty():
			data.chest_cells.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
		if not candidates.is_empty():
			data.npc_cell = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
			data.quest_cell = _farthest_free_cell(data)

	return data

# Case d'un portail : la plus loin de `from` a pied qui ne coupe pas l'etage quand on la bloque
# (en plus de `blocked`), ramenee au milieu de sa salle si ca ne coupe rien non plus.
static func _portal_cell(data: FloorData, rooms: Array, from: Vector2i, blocked: Array, avoid: Array) -> Vector2i:
	var dist := _walk_distances(data, from, [])
	var cells: Array = data.floor_cells.keys()
	cells.sort()  # meme etage pour une meme graine
	cells.sort_custom(func(a, b): return dist.get(a, -1) > dist.get(b, -1))
	for cell in cells:
		if cell in avoid or not _keeps_connected(data, blocked + [cell]):
			continue
		for room in rooms:
			var center: Vector2i = room.position + room.size / 2
			if room.has_point(cell) and center not in avoid and _keeps_connected(data, blocked + [center]):
				return center
		return cell
	return from

static func _keeps_connected(data: FloorData, cut: Array) -> bool:
	return _walk_distances(data, data.spawn_cell, cut).size() == data.floor_cells.size() - cut.size()

# Distance a pied (en cases) depuis `from` vers chaque case accessible sans passer par `blocked`.
static func _walk_distances(data: FloorData, from: Vector2i, blocked: Array) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + dir
			if data.floor_cells.has(next) and not dist.has(next) and next not in blocked:
				dist[next] = dist[cell] + 1
				queue.append(next)
	return dist

static func _farthest_free_cell(data: FloorData) -> Vector2i:
	var reserved := [data.spawn_cell, data.exit_cell, data.secondary_cell, data.npc_cell] + data.chest_cells
	var best := NONE
	var best_dist := -1.0
	var cells: Array = data.floor_cells.keys()
	cells.sort()
	for cell in cells:
		var dist := Vector2(cell - data.npc_cell).length_squared()
		if cell not in reserved and dist > best_dist:
			best_dist = dist
			best = cell
	return best

static func _overlaps_any(rect: Rect2i, rooms: Array, margin: int) -> bool:
	var expanded := Rect2i(rect.position - Vector2i(margin, margin), rect.size + Vector2i(margin, margin) * 2)
	for other in rooms:
		if expanded.intersects(other):
			return true
	return false

static func _carve_corridor(data: FloorData, from: Vector2i, to: Vector2i, width: int) -> void:
	var x := from.x
	var y := from.y
	_carve_cell(data, Vector2i(x, y), width)
	while x != to.x:
		x += sign(to.x - x)
		_carve_cell(data, Vector2i(x, y), width)
	while y != to.y:
		y += sign(to.y - y)
		_carve_cell(data, Vector2i(x, y), width)

static func _carve_cell(data: FloorData, center: Vector2i, width: int) -> void:
	var half := width / 2
	for dx in range(-half, half + 1):
		for dy in range(-half, half + 1):
			var cell := center + Vector2i(dx, dy)
			if cell.x > 0 and cell.x < data.size.x - 1 and cell.y > 0 and cell.y < data.size.y - 1:
				data.floor_cells[cell] = true
