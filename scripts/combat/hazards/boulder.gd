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
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color.darkened(0.4), 3.0)
	draw_line(Vector2(-radius * 0.6, 0), Vector2(radius * 0.6, 0), color.lightened(0.3), 3.0)
