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
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var b := TAU * (i + 1) / SEGMENTS
		if in_gap((a + b) / 2.0):
			continue
		draw_line(Vector2.from_angle(a) * radius, Vector2.from_angle(b) * radius, Color(color, 0.85), THICKNESS)
