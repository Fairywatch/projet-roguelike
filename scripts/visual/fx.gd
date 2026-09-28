class_name Fx
extends RefCounted

# Petits effets de "juice" partages entre combat et exploration.

const FlashShader := preload("res://assets/shaders/flash.gdshader")

static func make_flash_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FlashShader
	return material

# Fait flasher un sprite qui porte un materiau de make_flash_material().
static func flash(sprite: CanvasItem, color: Color = Color.WHITE, duration: float = 0.1) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null or not Settings.enabled("flashes"):
		return
	material.set_shader_parameter("flash_color", color)
	material.set_shader_parameter("flash", 1.0)
	var tween := sprite.create_tween()
	tween.tween_method(func(v: float): material.set_shader_parameter("flash", v), 1.0, 0.0, duration)

# Petit arret sur image a l'impact : donne du poids aux coups.
static func hitstop(tree: SceneTree, duration: float = 0.05) -> void:
	if not Settings.enabled("hitstop"):
		return
	Engine.time_scale = 0.05
	await tree.create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

static func puff(parent: Node, at: Vector2, color: Color, amount: int = 14) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.5
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.damping_min = 80.0
	p.damping_max = 120.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = color
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.global_position = at
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

# Ombre ovale au sol, a dessiner dans le _draw() du parent (donc sous le sprite).
static func draw_shadow(canvas: CanvasItem, y: float, width: float) -> void:
	canvas.draw_set_transform(Vector2(0, y), 0.0, Vector2(1.0, 0.35))
	canvas.draw_circle(Vector2.ZERO, width / 2.0, Color(0, 0, 0, 0.35))
	canvas.draw_set_transform(Vector2.ZERO)
