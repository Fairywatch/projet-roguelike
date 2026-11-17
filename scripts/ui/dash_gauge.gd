class_name DashGauge
extends Control

# Jauge de recharge du dash, sous les coeurs. Elle brille un instant quand le dash est pret.

const SIZE := Vector2(54, 5)
const BACK := Color(0.1, 0.07, 0.18, 0.9)
var fill := Color(0.5, 0.82, 1)
var charging := Color(0.35, 0.5, 0.75)

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
	draw_rect(Rect2(Vector2(-1, -1), SIZE + Vector2(2, 2)), Color(0.05, 0.02, 0.08))
	draw_rect(Rect2(Vector2.ZERO, SIZE), BACK)
	var color := fill if ratio >= 1.0 else charging
	color = color.lerp(Color.WHITE, ready_flash / 0.3)
	draw_rect(Rect2(0, 0, SIZE.x * ratio, SIZE.y), color)
	draw_rect(Rect2(0, 0, SIZE.x * ratio, 1), Color(1, 1, 1, 0.35))
