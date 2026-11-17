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

# Petit arret sur image a l'impact : donne du poids aux coups. Plusieurs coups rapproches (un
# coup qui touche trois ennemis) ne s'additionnent pas : on prolonge seulement si le nouveau
# demande plus long, et seul le dernier remet le temps en marche (sinon le premier relancait le
# jeu au milieu de l'arret du second, ce qui donnait des saccades).
static var _stop_id := 0
static var _stop_until := 0

static func hitstop(tree: SceneTree, duration: float = 0.05) -> void:
	if not Settings.enabled("hitstop"):
		return
	var now := Time.get_ticks_msec()
	var until := now + int(duration * 1000.0)
	if until <= _stop_until:
		return
	_stop_until = until
	_stop_id += 1
	var id := _stop_id
	Engine.time_scale = 0.05
	await tree.create_timer((until - now) / 1000.0, true, false, true).timeout
	if id == _stop_id:
		Engine.time_scale = 1.0

# Copie fantome d'un sprite, laissee sur place et qui s'efface : images remanentes du dash,
# eclat d'un ennemi qui meurt. grow > 1 : elle gonfle en disparaissant.
static func ghost(source: Node2D, color: Color, duration: float, grow: float = 1.0) -> void:
	if not source.is_inside_tree():
		return
	var copy := Sprite2D.new()
	if source is AnimatedSprite2D:
		copy.texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	elif source is Sprite2D:
		copy.texture = source.texture
		copy.hframes = source.hframes
		copy.vframes = source.vframes
		copy.frame = source.frame
	else:
		return
	copy.flip_h = source.flip_h
	copy.offset = source.offset
	copy.modulate = color
	var host: Node = source.get_tree().current_scene
	if host == null and source.get_parent() != null:
		host = source.get_parent().get_parent()
	if host == null:
		return
	host.add_child(copy)
	copy.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	copy.global_transform = source.global_transform
	var tween := copy.create_tween().set_parallel()
	tween.tween_property(copy, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	if grow != 1.0:
		tween.tween_property(copy, "scale", copy.scale * grow, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(copy.queue_free)

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
