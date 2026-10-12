class_name Hazards
extends RefCounted

# Boite a outils des attaques ennemies, partagee par tout le bestiaire : projectiles (y compris
# des mots), anneaux d'onde de choc avec des trous, rayons, zones au sol (degats ou ralentissement).
# Chaque danger annonce sa frappe (telegraphe) avant de blesser : la lisibilite passe avant tout.

const ProjectileScene := preload("res://scenes/combat/Projectile.tscn")
const RingWave := preload("res://scripts/combat/hazards/ring_wave.gd")
const Beam := preload("res://scripts/combat/hazards/beam.gd")
const Zone := preload("res://scripts/combat/hazards/zone.gd")
const Sweep := preload("res://scripts/combat/hazards/sweep.gd")
const Shrink := preload("res://scripts/combat/hazards/shrink.gd")
# Surface jouable de l'arene (900 x 540 moins une marge).
const ARENA := Rect2(50, 50, 800, 440)

static func _scene() -> Node:
	return (Engine.get_main_loop() as SceneTree).current_scene

# Le vrai joueur (les mobs peuvent viser un leurre, mais les effets s'appliquent au joueur).
static func player() -> Node2D:
	return (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player")

static func clamp_to_arena(pos: Vector2) -> Vector2:
	return pos.clamp(ARENA.position, ARENA.end)

static func shoot(source: Node2D, direction: Vector2, speed: float = 170.0, color: Color = Color(0.75, 0.8, 1, 0.9), text: String = "") -> Area2D:
	var projectile: Area2D = ProjectileScene.instantiate()
	projectile.direction = direction.normalized()
	projectile.speed = speed
	projectile.source = source
	projectile.lifetime = 3.5
	_scene().add_child(projectile)
	projectile.global_position = source.global_position + projectile.direction * 22.0
	var visual: Polygon2D = projectile.get_node("Visual")
	visual.color = color
	if text != "":
		visual.visible = false
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
		label.add_theme_constant_override("outline_size", 4)
		label.position = Vector2(-label.get_minimum_size().x / 2.0, -8)
		projectile.add_child(label)
	return projectile

# Salve en eventail centree sur direction.
static func fan(source: Node2D, direction: Vector2, count: int, spread_degrees: float, speed: float, color: Color, texts: Array = []) -> void:
	for i in count:
		var t := 0.0 if count == 1 else float(i) / (count - 1) - 0.5
		var text: String = texts[i % texts.size()] if not texts.is_empty() else ""
		shoot(source, direction.rotated(deg_to_rad(spread_degrees) * t), speed, color, text)

# Couronne de projectiles dans toutes les directions.
static func radial(source: Node2D, count: int, speed: float, color: Color, offset: float = 0.0, texts: Array = []) -> void:
	for i in count:
		var text: String = texts[i % texts.size()] if not texts.is_empty() else ""
		shoot(source, Vector2.from_angle(offset + TAU * i / count), speed, color, text)

# Anneau qui s'elargit ; gaps = [[angle, demi-largeur en radians], ...] : les trous pour passer.
static func ring(center: Vector2, speed: float, gaps: Array = [], color: Color = Color(1, 0.85, 0.5)) -> Node2D:
	var wave: Node2D = RingWave.new()
	wave.speed = speed
	wave.gaps = gaps
	wave.color = color
	_scene().add_child(wave)
	wave.global_position = center
	return wave

static func beam(origin: Vector2, direction: Vector2, width: float, telegraph: float, active: float, color: Color = Color(0.6, 0.8, 1)) -> Node2D:
	var b: Node2D = Beam.new()
	b.direction = direction.normalized()
	b.width = width
	b.telegraph = telegraph
	b.active = active
	b.color = color
	_scene().add_child(b)
	b.global_position = origin
	return b

# kind : "damage" (blesse au contact une fois armee), "slow" (ralentit tant qu'on est dedans)
# ou "push" (pousse le joueur dans la direction push).
static func zone(center: Vector2, radius: float, kind: String, arm_delay: float, active_time: float, color: Color, push: Vector2 = Vector2.ZERO) -> Node2D:
	var z: Node2D = Zone.new()
	z.push = push
	z.radius = radius
	z.kind = kind
	z.arm_delay = arm_delay
	z.active_time = active_time
	z.color = color
	_scene().add_child(z)
	z.global_position = center
	return z

# Bras rotatif autour de center. swing > 0 : oscille de +/- swing radians au lieu de tourner.
static func sweep(center: Vector2, angle: float, angular_speed: float, length: float, width: float, telegraph: float, duration: float, color: Color = Color(1, 0.85, 0.5), swing: float = 0.0) -> Node2D:
	var s: Node2D = Sweep.new()
	s.angle = angle
	s.angular_speed = angular_speed
	s.swing = swing
	s.length = length
	s.width = width
	s.telegraph = telegraph
	s.duration = duration
	s.color = color
	_scene().add_child(s)
	s.global_position = center
	return s

# L'arene se resserre jusqu'a stop() (voir hazards/shrink.gd).
static func shrink(speed: float = 18.0, telegraph: float = 1.0) -> Node2D:
	var s: Node2D = Shrink.new()
	s.speed = speed
	s.telegraph = telegraph
	_scene().add_child(s)
	return s
