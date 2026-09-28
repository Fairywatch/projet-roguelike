extends Node2D

# Dessine l'etage avec les tuiles du theme : sol, murs vus de dessus, et facade des murs
# qui surplombent une case de sol (effet de profondeur facon vue 3/4).

const SHADOW_HEIGHT := 18.0

var floor_cells: Dictionary = {}
var grid_size := Vector2i.ZERO
var floor_textures: Array = []
var wall_top: Texture2D
var wall_face: Texture2D
var cell_seed := 0

func setup(cells: Dictionary, size: Vector2i, family: int, intensity: int, seed_value: int) -> void:
	floor_cells = cells
	grid_size = size
	var theme := DreamTheme.theme_name(family, intensity)
	floor_textures = DreamTheme.floor_textures(theme)
	wall_top = DreamTheme.wall_texture(theme, "top")
	wall_face = DreamTheme.wall_texture(theme, "face")
	cell_seed = seed_value
	queue_redraw()

func _draw() -> void:
	var cell_size := FloorGenerator.CELL_SIZE
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			if floor_cells.has(cell):
				var tex: Texture2D = floor_textures[hash(Vector3i(x, y, cell_seed)) % floor_textures.size()]
				draw_texture_rect(tex, rect, false)
				if not floor_cells.has(cell + Vector2i.UP):
					_draw_shadow(rect)
			elif floor_cells.has(cell + Vector2i.DOWN):
				draw_texture_rect(wall_face, rect, false)
			else:
				draw_texture_rect(wall_top, rect, false)

func _draw_shadow(rect: Rect2) -> void:
	for i in int(SHADOW_HEIGHT / 2):
		var a := 0.4 * (1.0 - float(i) / (SHADOW_HEIGHT / 2))
		draw_rect(Rect2(rect.position.x, rect.position.y + i * 2, rect.size.x, 2), Color(0, 0, 0, a))
