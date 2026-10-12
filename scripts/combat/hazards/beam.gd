extends Node2D

# Rayon en ligne droite : un trait fin clignote pendant le telegraphe, puis le rayon frappe.
# Voir Hazards.beam().

const LENGTH := 1000.0

var direction := Vector2.RIGHT
var width := 26.0
var telegraph := 0.8
var active := 0.35
var color := Color(0.6, 0.8, 1)
var t := 0.0
var hit := false

func _physics_process(delta: float) -> void:
	t += delta
	if t > telegraph + active:
		queue_free()
		return
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p and not hit and t >= telegraph:
		var local := (p.global_position - global_position).rotated(-direction.angle())
		if local.x >= 0.0 and local.x <= LENGTH and absf(local.y) <= width / 2.0 + 10.0:
			hit = true
			p.take_damage()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, direction.angle())
	if t < telegraph:
		var blink := 0.35 + 0.35 * absf(sin(t * 18.0))
		draw_line(Vector2.ZERO, Vector2(LENGTH, 0), Color(color, blink), 2.0)
	else:
		draw_rect(Rect2(0, -width / 2.0, LENGTH, width), Color(color, 0.75))
		draw_rect(Rect2(0, -width / 6.0, LENGTH, width / 3.0), Color(1, 1, 1, 0.8))
