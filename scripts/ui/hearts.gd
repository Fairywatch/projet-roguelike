class_name Hearts
extends Control

# PV en coeurs pixel art, facon Isaac : un coeur par PV max, vide quand il est perdu.
# Un coeur perdu tremble et blanchit un instant ; un coeur regagne grossit puis se pose ;
# au dernier PV, le coeur restant bat.

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
const LOST_TIME := 0.4
const GAIN_TIME := 0.3

var hp := 3:
	set(value):
		if primed and value != hp:
			for i in range(mini(value, hp), maxi(value, hp)):
				effects[i] = [-LOST_TIME if value < hp else GAIN_TIME, 0.0]
		hp = value
		queue_redraw()
var max_hp := 3:
	set(value):
		max_hp = value
		custom_minimum_size = Vector2(max_hp * (SHAPE[0].length() * PIXEL + GAP) - GAP, SHAPE.size() * PIXEL)
		queue_redraw()
# Les premieres valeurs (mise en place de la scene) ne s'animent pas.
var primed := false
# index du coeur -> [duree signee (negative : perdu), temps ecoule]
var effects := {}
var beat := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	primed = true
	beat += delta
	for i in effects.keys():
		effects[i][1] += delta
		if effects[i][1] >= absf(effects[i][0]):
			effects.erase(i)
	if not effects.is_empty() or hp == 1:
		queue_redraw()

func _draw() -> void:
	var width: float = SHAPE[0].length() * PIXEL + GAP
	var center := Vector2(SHAPE[0].length(), SHAPE.size()) * PIXEL / 2.0
	for i in max_hp:
		var full := i < hp
		var offset := Vector2(i * width, 0)
		var grow := 1.0
		var whiten := 0.0
		if effects.has(i):
			var duration: float = effects[i][0]
			var t: float = effects[i][1] / absf(duration)
			if duration < 0.0:  # perdu : tremble, blanchit, puis s'eteint
				offset.x += sin(t * 40.0) * 2.0 * (1.0 - t)
				offset.y += t * 2.0 * (1.0 - t) * 4.0
				whiten = 1.0 - t
				full = t < 0.25
			else:  # regagne : grossit puis se pose
				grow = 1.0 + 0.45 * (1.0 - t) * (1.0 - t)
				whiten = (1.0 - t) * 0.6
		elif full and hp == 1:
			grow = 1.0 + 0.1 * maxf(0.0, sin(beat * 7.0))
		draw_set_transform(offset + center, 0.0, Vector2(grow, grow))
		for y in SHAPE.size():
			for x in SHAPE[y].length():
				var c: String = SHAPE[y][x]
				if c == ".":
					continue
				var color := OUTLINE if c == "O" else (EMPTY if not full else (SHINE if c == "H" else FULL))
				if c != "O" and whiten > 0.0:
					color = color.lerp(Color.WHITE, whiten)
				draw_rect(Rect2(Vector2(x, y) * PIXEL - center, Vector2(PIXEL, PIXEL)), color)
	draw_set_transform(Vector2.ZERO)
