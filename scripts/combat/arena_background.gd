extends Node2D

const ARENA_WIDTH := 900
const ARENA_HEIGHT := 540
const CELL_SIZE := 60
const COLOR_A := Color(0.18, 0.08, 0.1, 1)
const COLOR_B := Color(0.22, 0.1, 0.12, 1)
const BORDER_COLOR := Color(1, 1, 1, 0.6)

func _draw() -> void:
	var cols := ARENA_WIDTH / CELL_SIZE
	var rows := ARENA_HEIGHT / CELL_SIZE
	for y in rows:
		for x in cols:
			var color := COLOR_A if (x + y) % 2 == 0 else COLOR_B
			draw_rect(Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE), color)
	draw_rect(Rect2(0, 0, ARENA_WIDTH, ARENA_HEIGHT), BORDER_COLOR, false, 4.0)
