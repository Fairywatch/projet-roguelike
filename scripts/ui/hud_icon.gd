class_name HudIcon
extends Control

# Petites icones pixel art du HUD, dessinees comme les coeurs (Hearts) : piece, gemme (objets
# passifs), crane (ennemis restants), et les pastilles de charges de l'objet actif.

const PIXEL := 2.0
const OUTLINE := Color(0.17, 0.13, 0.25)
const SHAPES := {
	"coin": [
		".OOOO.",
		"OYWYYO",
		"OWYYDO",
		"OYYYDO",
		"OYYDDO",
		".OOOO.",
	],
	"gem": [
		"..OO..",
		".OWVO.",
		"OWVVVO",
		"OVVVDO",
		".OVDO.",
		"..OO..",
	],
	"skull": [
		".OOOOOO.",
		"OWWWWWWO",
		"OWEEWEEO",
		"OWEEWEEO",
		"OWWWWWWO",
		".OWWWWO.",
		".OWOWOO.",
		"..OOOO..",
	],
}
const COLORS := {
	"coin": {"Y": Color(1, 0.8, 0.3), "W": Color(1, 0.96, 0.75), "D": Color(0.82, 0.52, 0.16)},
	"gem": {"V": Color(0.66, 0.55, 1), "W": Color(0.92, 0.9, 1), "D": Color(0.42, 0.32, 0.8)},
	"skull": {"W": Color(0.93, 0.9, 0.98), "E": Color(0.3, 0.12, 0.32)},
}
const PIP := Color(0.92, 0.66, 0.2)
const PIP_EMPTY := Color(0.86, 0.8, 0.68)

var kind := "coin"
# Pastilles ("pips") : charges restantes / maximum.
var value := 0:
	set(v):
		value = v
		queue_redraw()
var max_value := 0:
	set(v):
		max_value = v
		_resize()

static func make(icon_kind: String) -> HudIcon:
	var icon := HudIcon.new()
	icon.kind = icon_kind
	return icon

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_resize()

func _resize() -> void:
	if kind == "pips":
		custom_minimum_size = Vector2(maxi(max_value, 0) * 10.0, 8.0)
	else:
		custom_minimum_size = Vector2(SHAPES[kind][0].length(), SHAPES[kind].size()) * PIXEL
	queue_redraw()

func _draw() -> void:
	if kind == "pips":
		for i in max_value:  # carres de 8 : cerne d'encre, rempli au crayon si la charge reste
			var at := Vector2(i * 10.0, 0.0)
			draw_rect(Rect2(at, Vector2(8, 8)), OUTLINE)
			draw_rect(Rect2(at + Vector2(2, 2), Vector2(4, 4)), PIP if i < value else PIP_EMPTY)
		return
	var shape: Array = SHAPES[kind]
	var colors: Dictionary = COLORS[kind]
	for y in shape.size():
		for x in shape[y].length():
			var c: String = shape[y][x]
			if c == ".":
				continue
			draw_rect(Rect2(x * PIXEL, y * PIXEL, PIXEL, PIXEL), OUTLINE if c == "O" else colors[c])
