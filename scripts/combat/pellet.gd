class_name Pellet
extends Area2D

# Petit oreiller du Lance-pierre (style fronde) : l'attaque du joueur, a distance. File tout droit en
# tournoyant (assets/sprites/player/oreiller.png, tools/gen_projectiles.py), touche le
# premier ennemi et creve en plumes, sur lui ou sur les murs. Le coup passe par le joueur
# (PlayerCombat.apply_hit) : critiques, soin, ralentissement et recul marchent comme au corps a
# corps. Les oreillers d'un meme tir partagent `shot` : un ennemi n'est touche qu'une fois par tir.

const SPEED := 520.0
const RADIUS := 8.0  # a peu pres le dessin (14 x 10 pixels d'art)
const COLOR := Color(0.92, 0.9, 1)  # plumes qui s'echappent
const HEAVY_TRAIL := Color(1, 0.85, 0.45)  # 3e coup : une trainee doree
const PillowTexture := preload("res://assets/sprites/player/oreiller.png")
const FRAMES := 4
const FRAME_RATE := 14.0

var direction := Vector2.RIGHT
var damage := 1
var heavy := false  # 3e coup : touche un peu plus large, trainee doree, coup "fort" (son, secousse)
var reach := 300.0
var shooter: Node  # le joueur
var shot: Dictionary = {}
var traveled := 0.0
var sprite := Sprite2D.new()
var phase := randi() % FRAMES  # les trois oreillers du 3e coup ne tournent pas ensemble

func _ready() -> void:
	monitorable = false
	sprite.texture = PillowTexture
	sprite.hframes = FRAMES
	sprite.frame = phase
	sprite.scale = Vector2(2, 2)  # pixel d'art = 2 unites
	add_child(sprite)
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
	sprite.frame = (int(traveled / SPEED * FRAME_RATE) + phase) % FRAMES
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
	Fx.puff(get_parent(), global_position, COLOR, 9)  # l'oreiller creve : des plumes
	queue_free()

# Trainee : trois carres de pixels qui s'effacent derriere l'oreiller (comme les tirs ennemis).
func _draw() -> void:
	var trail := HEAVY_TRAIL if heavy else COLOR
	for k in [3, 2, 1]:
		var side: float = 8.0 - k * 2.0 + (2.0 if heavy else 0.0)
		var at: Vector2 = (-direction * k * 8.0 / 2.0).round() * 2.0
		draw_rect(Rect2(at - Vector2.ONE * side / 2.0, Vector2.ONE * side), Color(trail, 0.5 - k * 0.12))
