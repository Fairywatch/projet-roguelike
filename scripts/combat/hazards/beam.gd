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
var art: ShaderMaterial

func _ready() -> void:
	z_index = -1  # au sol : sous les ennemis, le joueur et les projectiles (le fond est a -10)
	art = PixelFx.material(PixelFx.BEAM, color)
	art.set_shader_parameter("width", width)
	art.set_shader_parameter("beam_length", LENGTH)
	material = art

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
	# Pixel art (assets/shaders/pixel_beam.gdshader), le long de la direction du rayon.
	draw_set_transform(Vector2.ZERO, direction.angle())
	var active_t := t - telegraph
	art.set_shader_parameter("mode", 0 if t < telegraph else 1)
	if t < telegraph:
		art.set_shader_parameter("progress", t / maxf(telegraph, 0.01))
	else:
		var q := clampf(active_t / maxf(active, 0.01), 0.0, 1.0)
		art.set_shader_parameter("progress", (1.0 - smoothstep(0.75, 1.0, q)) * (0.9 + 0.1 * sin(t * 70.0)))
	art.set_shader_parameter("time", t)
	var half := width * 0.9 + 12.0
	draw_rect(Rect2(-half, -half, LENGTH + half, half * 2.0), Color.WHITE)
