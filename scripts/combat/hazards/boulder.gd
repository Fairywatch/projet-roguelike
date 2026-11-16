extends Node2D

# Rocher (le monde d'Atlas...) qui roule en ligne droite et rebondit sur les bords de l'arene ;
# il blesse au contact et disparait apres lifetime secondes. Voir Hazards.boulder().

const ARENA := Rect2(50, 50, 800, 440)  # meme surface que Hazards.ARENA

var direction := Vector2.RIGHT
var speed := 220.0
var radius := 26.0
var lifetime := 5.0
var color := Color(0.4, 0.6, 0.85)
var t := 0.0

func _physics_process(delta: float) -> void:
	t += delta
	if t > lifetime:
		queue_free()
		return
	var next := global_position + direction * speed * delta
	if next.x < ARENA.position.x or next.x > ARENA.end.x:
		direction.x = -direction.x
	if next.y < ARENA.position.y or next.y > ARENA.end.y:
		direction.y = -direction.y
	global_position = (global_position + direction * speed * delta).clamp(ARENA.position, ARENA.end)
	rotation += speed * delta / radius
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p and p.global_position.distance_to(global_position) < radius + 12.0:
		p.take_damage()
	queue_redraw()

func _draw() -> void:
	# L'ombre et la lumiere ne tournent pas avec le rocher ; ses fissures, si.
	draw_set_transform(Vector2(0, radius * 0.85).rotated(-rotation), -rotation, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 1.05, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, -rotation)
	draw_circle(Vector2.ZERO, radius + 2.0, HazardArt.outline(color))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(radius * 0.12, radius * 0.14), radius * 0.86, color.darkened(0.18))
	draw_circle(Vector2(-radius * 0.08, -radius * 0.1), radius * 0.8, color)
	draw_arc(Vector2.ZERO, radius * 0.7, -2.6, -1.5, 10, HazardArt.light(color, 0.8), 3.0)
	draw_set_transform(Vector2.ZERO)
	var crack := color.darkened(0.5)
	draw_polyline(PackedVector2Array([Vector2(-radius * 0.7, -radius * 0.1), Vector2(-radius * 0.25, radius * 0.1), Vector2(0, -radius * 0.15), Vector2(radius * 0.45, radius * 0.2)]), crack, 2.0)
	draw_line(Vector2(0, -radius * 0.15), Vector2(radius * 0.15, -radius * 0.6), crack, 2.0)
	draw_line(Vector2(-radius * 0.25, radius * 0.1), Vector2(-radius * 0.35, radius * 0.55), crack, 2.0)
