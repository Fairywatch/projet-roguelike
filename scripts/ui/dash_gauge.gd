class_name DashGauge
extends Control

# Jauge de recharge du dash (et de la rafale), sous les coeurs : un cadre d'encre sur le papier,
# rempli au crayon de couleur (hachures). Elle s'eclaire un instant quand elle est pleine.
# Tout tombe sur la grille des pixels d'art (2 pixels du jeu).

const SIZE := Vector2(54, 6)
const BACK := Color(0.86, 0.8, 0.68)
const INK := Color(0.17, 0.13, 0.25)
var fill := Color(0.32, 0.5, 0.82)
var charging := Color(0.55, 0.62, 0.75)

var ratio := 1.0:
	set(v):
		if v >= 1.0 and ratio < 1.0:
			ready_flash = 0.3
		ratio = clampf(v, 0.0, 1.0)
		queue_redraw()
var ready_flash := 0.0

func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if ready_flash > 0.0:
		ready_flash = maxf(0.0, ready_flash - delta)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2(-2, -2), SIZE + Vector2(4, 4)), INK)
	draw_rect(Rect2(Vector2.ZERO, SIZE), BACK)
	var color := fill if ratio >= 1.0 else charging
	color = color.lerp(Color.WHITE, ready_flash / 0.3)
	var width := floorf(SIZE.x * ratio / 2.0) * 2.0
	draw_rect(Rect2(0, 0, width, SIZE.y), color)
	var x := 0.0
	while x < width:  # hachures : un trait plus fonce tous les 6 pixels, en biais
		for row in 3:
			var hx := x + row * 2.0
			if hx < width:
				draw_rect(Rect2(hx, SIZE.y - 2.0 - row * 2.0, 2, 2), color.darkened(0.25))
		x += 6.0
