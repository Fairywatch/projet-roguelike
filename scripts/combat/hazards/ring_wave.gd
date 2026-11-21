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
var art: ShaderMaterial

func _ready() -> void:
	z_index = -1  # au sol : sous les ennemis, le joueur et les projectiles (le fond est a -10)
	art = PixelFx.material(PixelFx.RING, color)
	art.set_shader_parameter("thickness", THICKNESS)
	var packed := PackedVector2Array()
	for gap in gaps.slice(0, 4):
		packed.append(Vector2(gap[0], gap[1]))
	while packed.size() < 4:
		packed.append(Vector2.ZERO)
	art.set_shader_parameter("gaps", packed)
	art.set_shader_parameter("gap_count", mini(gaps.size(), 4))
	material = art

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
	# Pixel art (assets/shaders/pixel_ring.gdshader) : bande de trois tons, echo, trous marques.
	art.set_shader_parameter("radius", radius)
	art.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	var reach := radius + THICKNESS + 8.0
	draw_rect(Rect2(-reach, -reach, reach * 2.0, reach * 2.0), Color.WHITE)
