class_name DreamDecor
extends Area2D

# Decor d'etage avec lequel le joueur interagit en le touchant. La carte (map.gd) applique l'effet.

signal touched(decor: DreamDecor)

const RADIUS := 16.0
const PUSH_DISTANCE := 24.0

var decor_name := ""
var decor_id := 0
var family := 0
var lit := false
var sprite := Sprite2D.new()
var light: PointLight2D

func _ready() -> void:
	sprite.texture = DreamTheme.decor_texture(family, decor_name)
	sprite.scale = Vector2(2, 2)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = RADIUS
	add_child(shape)
	if decor_name in DreamTheme.FLOATING:
		var tween := sprite.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		var period := randf_range(1.2, 2.2)
		tween.tween_property(sprite, "position:y", -6.0, period)
		tween.tween_property(sprite, "position:y", 0.0, period)
	if DreamTheme.GLOWING.has(decor_name):
		light = DreamTheme.make_light(DreamTheme.GLOWING[decor_name], 50.0, 0.8)
		add_child(light)
	if lit:
		light_up()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or body.frozen:
		return
	_wobble()
	if decor_name in ["cube", "nuage"]:
		var away := (global_position - body.global_position).normalized() * PUSH_DISTANCE
		create_tween().tween_property(self, "position", position + away.round(), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif decor_name == "arbre_mort":
		Fx.puff(get_parent(), global_position, Color(0.45, 0.35, 0.3), 8)
	touched.emit(self)

func _wobble() -> void:
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(2.6, 1.5), 0.06)
	tween.tween_property(sprite, "scale", Vector2(2, 2), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# La bougie reste allumee plus fort apres le passage du joueur.
func light_up() -> void:
	lit = true
	if light:
		light.energy *= 2.0
		light.texture_scale *= 1.8

func vanish(color: Color) -> void:
	Fx.puff(get_parent(), global_position, color, 14)
	queue_free()
