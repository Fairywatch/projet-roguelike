class_name Feather
extends Area2D

# Plume de la Rafale (attaque speciale du joueur) : file tout droit, touche le premier ennemi
# (ou les traverse tous avec la Plume de paon) et se brise sur les murs. Un ennemi n'est touche
# qu'une fois par rafale, meme si plusieurs plumes l'atteignent : la rafale sert a toucher loin
# ou plusieurs ennemis, pas a doubler les degats au corps a corps.

const SPEED := 430.0
const RANGE := 270.0
const COLOR := Color(0.95, 0.92, 1)
const QUILL := Color(0.62, 0.52, 0.95)

var direction := Vector2.RIGHT
var damage := 1
var pierce := false
var volley: Dictionary = {}  # partage par les plumes d'une meme rafale : ennemis deja touches
var traveled := 0.0

func _ready() -> void:
	monitorable = false
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 7.0
	add_child(shape)
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	position += direction * step
	traveled += step
	if traveled >= RANGE:
		_vanish()

func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if not (target is BaseMob) or not area.has_method("register_hit"):
		return
	var id := target.get_instance_id()
	if volley.has(id):
		return
	volley[id] = true
	area.register_hit(damage)
	Sound.play("hit", -6.0)
	if not pierce:
		_vanish()

func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:  # murs de l'arene, murs des dangers
		_vanish()

func _vanish() -> void:
	if is_queued_for_deletion():
		return
	Fx.puff(get_parent(), global_position, COLOR, 5)
	queue_free()

func _draw() -> void:
	var fade := 1.0 - traveled / RANGE * 0.5
	draw_line(Vector2(-22, 0), Vector2(-4, 0), Color(COLOR, 0.25 * fade), 4.0)  # trainee
	draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(0, -4), Vector2(-9, -2), Vector2(-9, 2), Vector2(0, 4)]), Color(COLOR, fade))
	draw_line(Vector2(-11, 0), Vector2(8, 0), Color(QUILL, fade), 1.5)

func _process(_delta: float) -> void:
	queue_redraw()
