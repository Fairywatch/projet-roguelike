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
	var a := 0.3 if t < telegraph else 0.82
	# Quatre bandes sombres autour du rectangle encore sur...
	draw_rect(Rect2(outer.position, Vector2(outer.size.x, rect.position.y - outer.position.y)), Color(color, a))
	draw_rect(Rect2(Vector2(outer.position.x, rect.end.y), Vector2(outer.size.x, outer.end.y - rect.end.y)), Color(color, a))
	draw_rect(Rect2(Vector2(outer.position.x, rect.position.y), Vector2(rect.position.x - outer.position.x, rect.size.y)), Color(color, a))
	draw_rect(Rect2(Vector2(rect.end.x, rect.position.y), Vector2(outer.end.x - rect.end.x, rect.size.y)), Color(color, a))
	# ... dont le bord s'estompe vers l'interieur, par paliers.
	for k in 5:
		draw_rect(rect.grow(-3.0 - k * 5.0), Color(color, a * (0.36 - k * 0.07)), false, 6.0)
	# Des volutes de noir rampent le long du bord.
	var perimeter := (rect.size.x + rect.size.y) * 2.0
	for i in 26:
		var d := fmod(i * perimeter / 26.0 + t * 22.0, perimeter)
		var at := _on_border(d)
		var inward := (rect.get_center() - at).normalized()
		var reach := 10.0 + 9.0 * sin(t * 2.4 + i * 1.9)
		draw_circle(at + inward * reach * 0.5, 9.0 + 4.0 * sin(t * 3.1 + i), Color(color, a * 0.75))
	# La limite a ne pas franchir : pointilles pendant l'annonce, trait plein ensuite.
	var edge := Color(0.9, 0.3, 0.4, 0.5 + 0.4 * absf(sin(t * 6.0))) if t < telegraph else Color(0.9, 0.3, 0.4, 0.85)
	draw_rect(rect, edge, false, 3.0)
	draw_rect(rect.grow(-4.0), Color(1, 0.75, 0.8, edge.a * 0.35), false, 1.0)

# Point du bord a la distance d le long du perimetre.
func _on_border(d: float) -> Vector2:
	if d < rect.size.x:
		return rect.position + Vector2(d, 0)
	d -= rect.size.x
	if d < rect.size.y:
		return Vector2(rect.end.x, rect.position.y + d)
	d -= rect.size.y
	if d < rect.size.x:
		return Vector2(rect.end.x - d, rect.end.y)
	return Vector2(rect.position.x, rect.end.y - (d - rect.size.x))
