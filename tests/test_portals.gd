# Lancer : godot --headless --path . --script res://tests/test_portals.gd
extends SceneTree

# Les portails d'etage ne bloquent jamais rien (tout l'etage reste accessible sans les toucher)
# et le portail de sortie est au bout de l'etage, le plus loin possible du depart.

const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

func _distances(cells: Dictionary, from: Vector2i, blocked: Array) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for dir in DIRS:
			var next: Vector2i = cell + dir
			if cells.has(next) and not dist.has(next) and next not in blocked:
				dist[next] = dist[cell] + 1
				queue.append(next)
	return dist

func _initialize() -> void:
	var blocking := 0
	var not_far := 0
	for seed in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var data := FloorGenerator.generate(seed % 2, 0, rng, (seed % 5) / 4.0)
		var portals := [data.exit_cell, data.secondary_cell]
		var reach := _distances(data.floor_cells, data.spawn_cell, portals)
		if reach.size() != data.floor_cells.size() - 2:
			blocking += 1
		var from_spawn := _distances(data.floor_cells, data.spawn_cell, [])
		# Aucune case accessible n'est plus loin que le portail de sortie (a part les coins de sa salle).
		var without_exit := _distances(data.floor_cells, data.spawn_cell, [data.exit_cell])
		for cell in data.floor_cells:
			if from_spawn[cell] > from_spawn[data.exit_cell] + 4 and without_exit.has(cell):
				not_far += 1
				break
	print("etages ou un portail bloque un passage : %d / 300, sortie pas au bout : %d / 300" % [blocking, not_far])
	assert(blocking == 0 and not_far == 0)
	print("test_portals OK")
	quit()
