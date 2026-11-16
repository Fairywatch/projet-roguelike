extends Node2D

# Anneau d'onde de choc qui s'elargit depuis son centre. Blesse le joueur quand il le traverse,
# sauf dans les trous (gaps). Voir Hazards.ring().

const MAX_RADIUS := 700.0
const THICKNESS := 12.0
const SEGMENTS := 72

var speed := 150.0
var gaps: Array = []
var color := Color(1, 0.85, 0.5)
var radius := 10.0
var hit := false

func _physics_process(delta: float) -> void:
	radius += speed * delta
	if radius > MAX_RADIUS:
		queue_free()
		return
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p and not hit:
		var offset := p.global_position - global_position
		if absf(offset.length() - radius) < THICKNESS / 2.0 + 10.0 and not in_gap(offset.angle()):
			hit = true
			p.take_damage()
	queue_redraw()

func in_gap(angle: float) -> bool:
	for gap in gaps:
		if absf(angle_difference(angle, gap[0])) < gap[1]:
			return true
	return false

func _draw() -> void:
	# Chaque troncon plein de l'anneau : contour sombre, couleur, rehaut clair cote interieur, et
	# un echo pale derriere lui. Les bords des trous sont marques d'un point clair : on voit ou passer.
	var dark := HazardArt.outline(color, 0.8)
	var bright := HazardArt.light(color, 0.9)
	var run := PackedVector2Array()
	var inner := PackedVector2Array()
	var echo := PackedVector2Array()
	for i in SEGMENTS + 1:
		var a := TAU * i / SEGMENTS
		var open := i == SEGMENTS or in_gap(a)
		if not open:
			var dir := Vector2.from_angle(a)
			run.append(dir * radius)
			inner.append(dir * (radius - THICKNESS * 0.25))
			echo.append(dir * maxf(radius - 16.0, 0.0))
		if open or i == SEGMENTS - 1:
			if run.size() >= 2:
				if radius > 20.0:
					draw_polyline(echo, Color(color, 0.22), 4.0)
				draw_polyline(run, dark, THICKNESS + 4.0)
				draw_polyline(run, Color(color, 0.95), THICKNESS)
				draw_polyline(inner, bright, 3.0)
				if not gaps.is_empty():
					draw_circle(run[0], THICKNESS * 0.55, bright)
					draw_circle(run[run.size() - 1], THICKNESS * 0.55, bright)
			run = PackedVector2Array()
			inner = PackedVector2Array()
			echo = PackedVector2Array()
