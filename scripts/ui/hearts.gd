class_name Hearts
extends Control

# PV en coeurs pixel art, facon Isaac : un coeur par PV max, vide quand il est perdu.

const PIXEL := 2.0
const GAP := 2.0
const SHAPE := [
	".OO...OO.",
	"OHRO.ORRO",
	"ORRRORRRO",
	"ORRRRRRRO",
	".ORRRRRO.",
	"..ORRRO..",
	"...ORO...",
	"....O....",
]
const OUTLINE := Color(0.08, 0.03, 0.08)
const FULL := Color(0.93, 0.22, 0.32)
const SHINE := Color(1, 0.75, 0.78)
const EMPTY := Color(0.22, 0.14, 0.24, 0.85)

var hp := 3:
	set(value):
		hp = value
		queue_redraw()
var max_hp := 3:
	set(value):
		max_hp = value
		custom_minimum_size = Vector2(max_hp * (SHAPE[0].length() * PIXEL + GAP), SHAPE.size() * PIXEL)
		queue_redraw()

func _draw() -> void:
	var width: float = SHAPE[0].length() * PIXEL + GAP
	for i in max_hp:
		var full := i < hp
		for y in SHAPE.size():
			for x in SHAPE[y].length():
				var c: String = SHAPE[y][x]
				if c == ".":
					continue
				var color := OUTLINE if c == "O" else (EMPTY if not full else (SHINE if c == "H" else FULL))
				draw_rect(Rect2(i * width + x * PIXEL, y * PIXEL, PIXEL, PIXEL), color)
