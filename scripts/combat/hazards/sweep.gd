extends Node2D

# Bras rotatif (aiguille d'horloge, balancier...) : un trait pale pendant le telegraphe, puis
# un bras qui tourne autour de son centre et blesse ce qu'il balaie. Voir Hazards.sweep().
# swing > 0 : au lieu de tourner, le bras oscille de +/- swing radians (balancier).

var angle := 0.0
var angular_speed := 1.0
var swing := 0.0
var length := 400.0
var width := 18.0
var telegraph := 0.8
var duration := 3.0
var color := Color(1, 0.85, 0.5)
var t := 0.0
var start_angle := 0.0

func _ready() -> void:
	start_angle = angle

func _physics_process(delta: float) -> void:
	t += delta
	if t > telegraph + duration:
		queue_free()
		return
	if t >= telegraph:
		var active_t := t - telegraph
		angle = start_angle + (sin(active_t * angular_speed) * swing if swing > 0.0 else active_t * angular_speed)
		var p: Node2D = get_tree().get_first_node_in_group("player")
		if p:
			var local := (p.global_position - global_position).rotated(-angle)
			if local.x >= 0.0 and local.x <= length and absf(local.y) <= width / 2.0 + 10.0:
				p.take_damage()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, angle)
	if t < telegraph:
		draw_line(Vector2.ZERO, Vector2(length, 0), Color(color, 0.3 + 0.3 * absf(sin(t * 14.0))), 2.0)
	else:
		draw_rect(Rect2(0, -width / 2.0, length, width), Color(color, 0.8))
