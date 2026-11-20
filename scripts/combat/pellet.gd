class_name Pellet
extends Area2D

# Bille du Lance-pierre (style fronde) : l'attaque du joueur, a distance. File tout droit, touche le
# premier ennemi et se brise sur les murs. Le coup passe par le joueur (PlayerCombat.apply_hit) :
# critiques, soin, ralentissement et recul marchent comme au corps a corps. Les billes d'un meme
# tir partagent `shot` : un ennemi n'est touche qu'une fois par tir.

const SPEED := 520.0
const RADIUS := 6.0
const COLOR := Color(0.85, 0.9, 1)

var direction := Vector2.RIGHT
var damage := 1
var heavy := false  # 3e coup : un peu plus grosse, et le coup "fort" (son, secousse)
var reach := 300.0
var shooter: Node  # le joueur
var shot: Dictionary = {}
var traveled := 0.0

func _ready() -> void:
	monitorable = false
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = RADIUS + (2.0 if heavy else 0.0)
	add_child(shape)
	area_entered.connect(_on_area_entered)
	body_entered.connect(func(body): if body is StaticBody2D: _vanish())

func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	position += direction * step
	traveled += step
	if traveled >= reach:
		_vanish()
	queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if not (target is BaseMob) or not area.has_method("register_hit"):
		return
	if shot.has(target.get_instance_id()):
		return
	shot[target.get_instance_id()] = true
	if is_instance_valid(shooter) and shooter.has_method("apply_hit"):
		shooter.apply_hit(area, damage, heavy, direction)
	else:
		area.register_hit(damage)
	_vanish()

func _vanish() -> void:
	if is_queued_for_deletion():
		return
	Fx.puff(get_parent(), global_position, COLOR, 4)
	queue_free()

func _draw() -> void:
	var r := RADIUS + (2.0 if heavy else 0.0)
	for k in [3, 2, 1]:  # trainee
		draw_circle(-direction * k * 6.0, r - k * 1.2, Color(COLOR, 0.35 - k * 0.08))
	draw_circle(Vector2.ZERO, r + 1.5, Color(0.08, 0.05, 0.12, 0.85))
	draw_circle(Vector2.ZERO, r, COLOR)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color.WHITE)
