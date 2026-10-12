extends Node2D

# L'arene se resserre : un cadre sombre avance depuis les bords et blesse le joueur qui y reste.
# Un bord pale s'affiche d'abord (telegraphe). stop() fait reculer le cadre puis le retire.
# Voir Hazards.shrink().

const MIN_HALF_SIZE := Vector2(130, 90)
const ARENA := Rect2(50, 50, 800, 440)  # meme surface que Hazards.ARENA

var speed := 18.0  # pixels/s
var telegraph := 1.0
var color := Color(0.05, 0.03, 0.08)
var rect := ARENA
var t := 0.0
var retracting := false

func stop() -> void:
	retracting = true

func _physics_process(delta: float) -> void:
	t += delta
	var center := ARENA.get_center()
	var half := rect.size / 2.0
	if retracting:
		half += Vector2.ONE * speed * 6.0 * delta
		if half.x >= ARENA.size.x / 2.0:
			queue_free()
			return
	elif t >= telegraph:
		half = (half - Vector2.ONE * speed * delta).max(MIN_HALF_SIZE)
	rect = Rect2(center - half, half * 2.0)
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p and t >= telegraph and not retracting and not rect.grow(8.0).has_point(p.global_position):
		p.take_damage()
	queue_redraw()

func _draw() -> void:
	var outer := Rect2(Vector2(-200, -200), Vector2(1300, 940))
	var a := 0.25 if t < telegraph else 0.7
	# Quatre bandes sombres autour du rectangle encore sur.
	draw_rect(Rect2(outer.position, Vector2(outer.size.x, rect.position.y - outer.position.y)), Color(color, a))
	draw_rect(Rect2(Vector2(outer.position.x, rect.end.y), Vector2(outer.size.x, outer.end.y - rect.end.y)), Color(color, a))
	draw_rect(Rect2(Vector2(outer.position.x, rect.position.y), Vector2(rect.position.x - outer.position.x, rect.size.y)), Color(color, a))
	draw_rect(Rect2(Vector2(rect.end.x, rect.position.y), Vector2(outer.end.x - rect.end.x, rect.size.y)), Color(color, a))
	draw_rect(rect, Color(0.9, 0.3, 0.4, 0.8), false, 3.0)
