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
var art: ShaderMaterial

func _ready() -> void:
	start_angle = angle
	z_index = -1  # au sol : sous les ennemis, le joueur et les projectiles (le fond est a -10)
	art = PixelFx.material(PixelFx.BEAM, color)
	art.set_shader_parameter("width", width)
	art.set_shader_parameter("beam_length", length)
	art.set_shader_parameter("taper", 0.55)
	material = art

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
	# Pixel art (assets/shaders/pixel_beam.gdshader) : une lame qui s'affine, avec sa trainee.
	var half := width * 0.9 + 10.0
	art.set_shader_parameter("time", t)
	if t < telegraph:
		art.set_shader_parameter("mode", 0)
		art.set_shader_parameter("progress", t / maxf(telegraph, 0.01))
		draw_set_transform(Vector2.ZERO, start_angle)
		draw_rect(Rect2(-half, -half, length + half, half * 2.0), Color.WHITE)
		return
	art.set_shader_parameter("mode", 1)
	art.set_shader_parameter("progress", 1.0)
	var motion := angle - previous_angle
	for k in [3, 2, 1]:  # trainee : la lame aux positions d'avant, de plus en plus pale
		draw_set_transform(Vector2.ZERO, angle - motion * k * 2.2)
		draw_rect(Rect2(-half, -half, length + half, half * 2.0), Color(1, 1, 1, 0.12 * (4 - k)))
	draw_set_transform(Vector2.ZERO, angle)
	draw_rect(Rect2(-half, -half, length + half, half * 2.0), Color.WHITE)
