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
	var half := width / 2.0
	if t < telegraph:
		# Annonce : la largeur du rayon a venir, en transparence, et des tirets qui filent.
		var p := t / maxf(telegraph, 0.01)
		var urgent := p > 0.75 and int(t * 18.0) % 2 == 0
		draw_rect(Rect2(0, -half, LENGTH, width), Color(color, 0.06 + 0.12 * p))
		for side in [-1.0, 1.0]:
			draw_line(Vector2(0, side * half), Vector2(LENGTH, side * half), Color(color, 0.25 + 0.3 * p), 1.0)
		draw_set_transform(Vector2.ZERO, direction.angle())
		HazardArt.dashed_line(self, LENGTH, HazardArt.light(color) if urgent else Color(color, 0.9), 2.0, 14.0, 10.0, t * 260.0)
		draw_circle(Vector2.ZERO, 3.0 + 4.0 * p, Color(HazardArt.light(color), 0.5 + 0.4 * p))
		return
	# Frappe : un halo, le corps du rayon, un coeur blanc, des etincelles qui remontent le rayon.
	var q := clampf((t - telegraph) / maxf(active, 0.01), 0.0, 1.0)
	var power := (1.0 - smoothstep(0.75, 1.0, q)) * (0.9 + 0.1 * sin(t * 70.0))
	draw_rect(Rect2(0, -half * 1.7, LENGTH, width * 1.7), Color(color, 0.22 * power))
	draw_rect(Rect2(0, -half - 1.5, LENGTH, width + 3.0), HazardArt.outline(color, 0.7 * power))
	draw_rect(Rect2(0, -half, LENGTH, width), Color(color, 0.9 * power))
	draw_rect(Rect2(0, -half * 0.4, LENGTH, width * 0.4), Color(1, 1, 1, 0.9 * power))
	for i in 7:
		var x := fmod(t * 900.0 + i * 143.0, LENGTH)
		var y := half * 0.7 * sin(i * 2.3)
		draw_line(Vector2(x, y), Vector2(x + 22.0, y), Color(1, 1, 1, 0.7 * power), 2.0)
	draw_circle(Vector2.ZERO, half * 1.5, Color(color, 0.6 * power))
	draw_circle(Vector2.ZERO, half * 0.9, Color(1, 1, 1, 0.9 * power))
