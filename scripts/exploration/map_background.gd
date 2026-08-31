extends Node2D

var floor_cells: Dictionary = {}
var grid_width := 0
var grid_height := 0
var floor_color_a := Color(0.12, 0.12, 0.22, 1)
var floor_color_b := Color(0.16, 0.16, 0.28, 1)
var wall_color := Color(0.06, 0.06, 0.08, 1)

func setup(cells: Dictionary, width: int, height: int, intensity: int) -> void:
	floor_cells = cells
	grid_width = width
	grid_height = height
	if intensity == FloorGenerator.Intensity.REVE:
		floor_color_a = Color(0.5, 0.56, 0.72, 1)
		floor_color_b = Color(0.58, 0.63, 0.78, 1)
		wall_color = Color(0.32, 0.35, 0.46, 1)
	else:
		floor_color_a = Color(0.14, 0.05, 0.07, 1)
		floor_color_b = Color(0.18, 0.07, 0.09, 1)
		wall_color = Color(0.05, 0.02, 0.03, 1)
	queue_redraw()

func _draw() -> void:
	var cell_size := FloorGenerator.CELL_SIZE
	for y in grid_height:
		for x in grid_width:
			var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			if floor_cells.has(Vector2i(x, y)):
				var color := floor_color_a if (x + y) % 2 == 0 else floor_color_b
				draw_rect(rect, color)
			else:
				draw_rect(rect, wall_color)
