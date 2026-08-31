class_name FloorGenerator
extends RefCounted

enum Family { PARADOXAL, PROFOND }
enum Intensity { REVE, CAUCHEMAR }

const GRID_WIDTH := 32
const GRID_HEIGHT := 19
const CELL_SIZE := 100
const MAX_ROOM_ATTEMPTS := 400

class FloorData:
	var family: int
	var intensity: int
	var floor_cells: Dictionary = {}
	var spawn_cell: Vector2i = Vector2i.ZERO
	var exit_cell: Vector2i = Vector2i.ZERO
	var secondary_cell: Vector2i = Vector2i.ZERO

static func generate(family: int, intensity: int, rng: RandomNumberGenerator) -> FloorData:
	var data := FloorData.new()
	data.family = family
	data.intensity = intensity

	var room_count: int
	var room_min: int
	var room_max: int
	var corridor_width: int
	if family == Family.PARADOXAL:
		room_count = rng.randi_range(15, 20)
		room_min = 2
		room_max = 3
		corridor_width = 1
	else:
		room_count = rng.randi_range(8, 12)
		room_min = 3
		room_max = 5
		corridor_width = 2

	var rooms: Array = []
	var attempts := 0
	while rooms.size() < room_count and attempts < MAX_ROOM_ATTEMPTS:
		attempts += 1
		var w := rng.randi_range(room_min, room_max)
		var h := rng.randi_range(room_min, room_max)
		var x := rng.randi_range(1, GRID_WIDTH - w - 1)
		var y := rng.randi_range(1, GRID_HEIGHT - h - 1)
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
		data.exit_cell = data.spawn_cell
		var farthest_dist := -1.0
		for room in rooms:
			var center: Vector2i = room.position + room.size / 2
			var dist: float = Vector2(center - data.spawn_cell).length_squared()
			if dist > farthest_dist:
				farthest_dist = dist
				data.exit_cell = center

		data.secondary_cell = data.exit_cell
		var farthest_dist2 := -1.0
		for room in rooms:
			var center: Vector2i = room.position + room.size / 2
			if center == data.exit_cell or center == data.spawn_cell:
				continue
			var dist2: float = Vector2(center - data.exit_cell).length_squared()
			if dist2 > farthest_dist2:
				farthest_dist2 = dist2
				data.secondary_cell = center

	return data

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
			if cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT:
				data.floor_cells[cell] = true
