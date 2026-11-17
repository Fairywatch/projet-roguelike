class_name OffscreenMarkers
extends Control

# L'arene (900 x 540) est plus grande que l'ecran (640 x 360) : chaque ennemi hors champ est
# signale par une fleche au bord de l'ecran, dans sa direction. Elle rougit et clignote quand il
# prepare ou porte une attaque ; celle d'un boss est plus grande.

const INSET := 12.0
const SIZE := 7.0
const CALM := Color(1, 1, 1, 0.55)
const DANGER := Color(1, 0.4, 0.3, 0.95)
const OUTLINE := Color(0.08, 0.03, 0.1, 0.85)

var time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var screen := get_viewport_rect()
	var inner := screen.grow(-INSET)
	var center := screen.get_center()
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.state == BaseMob.State.DEAD or not mob.is_inside_tree():
			continue
		var at: Vector2 = mob.get_global_transform_with_canvas().origin
		if screen.grow(-4.0).has_point(at):
			continue
		var direction := (at - center).normalized()
		# Point du bord interieur dans la direction de l'ennemi.
		var scale_x := (inner.size.x / 2.0) / maxf(absf(direction.x), 0.0001)
		var scale_y := (inner.size.y / 2.0) / maxf(absf(direction.y), 0.0001)
		var edge := center + direction * minf(scale_x, scale_y)
		var danger: bool = mob.state == BaseMob.State.TELEGRAPH or mob.state == BaseMob.State.ATTACK
		var color := CALM
		if danger:
			color = DANGER if int(time * 8.0) % 2 == 0 else Color(1, 0.85, 0.4, 0.95)
		var size := SIZE * (1.5 if mob.is_boss else 1.0) * (1.25 if danger else 1.0)
		var tip := edge + direction * size
		var side := direction.orthogonal() * size * 0.75
		var back := edge - direction * size * 0.6
		var arrow := PackedVector2Array([tip, back + side, back - side])
		draw_colored_polygon(PackedVector2Array([tip + direction * 1.5, back + side * 1.3 - direction, back - side * 1.3 - direction]), OUTLINE)
		draw_colored_polygon(arrow, color)
