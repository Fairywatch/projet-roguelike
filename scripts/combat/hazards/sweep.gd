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
var previous_angle := 0.0  # angle a l'image precedente : la trainee suit le mouvement

func _ready() -> void:
	start_angle = angle

func _physics_process(delta: float) -> void:
	t += delta
	if t > telegraph + duration:
		queue_free()
		return
	if t >= telegraph:
		var active_t := t - telegraph
		previous_angle = angle
		angle = start_angle + (sin(active_t * angular_speed) * swing if swing > 0.0 else active_t * angular_speed)
		var p: Node2D = get_tree().get_first_node_in_group("player")
		if p:
			var local := (p.global_position - global_position).rotated(-angle)
			if local.x >= 0.0 and local.x <= length and absf(local.y) <= width / 2.0 + 10.0:
				p.take_damage()
	queue_redraw()

func _draw() -> void:
	var half := width / 2.0
	if t < telegraph:
		# Annonce : la lame en transparence, la ou elle va partir, et des tirets.
		var p := t / maxf(telegraph, 0.01)
		draw_set_transform(Vector2.ZERO, start_angle)
		draw_colored_polygon(HazardArt.blade(length, half + 2.0, half * 0.5), Color(color, 0.08 + 0.14 * p))
		HazardArt.dashed_line(self, length, Color(color, 0.85) if int(t * 14.0) % 2 == 0 or p < 0.75 else HazardArt.light(color), 2.0, 12.0, 9.0, t * 200.0)
		draw_circle(Vector2.ZERO, half + 2.0, Color(color, 0.5))
		return
	# Frappe : la lame, avec la trainee de son mouvement derriere elle.
	var motion := angle - previous_angle
	for k in [3, 2, 1]:
		draw_set_transform(Vector2.ZERO, angle - motion * k * 2.2)
		draw_colored_polygon(HazardArt.blade(length, half, half * 0.45), Color(color, 0.07 * (4 - k)))
	draw_set_transform(Vector2.ZERO, angle)
	draw_colored_polygon(HazardArt.blade(length + 2.0, half + 2.5, half * 0.45 + 2.0), HazardArt.outline(color))
	draw_colored_polygon(HazardArt.blade(length, half, half * 0.45), Color(color, 0.95))
	draw_line(Vector2(half, 0), Vector2(length * 0.9, 0), HazardArt.light(color, 0.9), 2.0)
	draw_circle(Vector2.ZERO, half + 4.0, HazardArt.outline(color))
	draw_circle(Vector2.ZERO, half + 2.0, color)
	draw_circle(Vector2.ZERO, half * 0.5, HazardArt.light(color))
