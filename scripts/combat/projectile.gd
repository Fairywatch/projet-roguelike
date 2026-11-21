extends Area2D

var direction := Vector2.RIGHT
var speed := 220.0
var lifetime := 2.0
var source: Node = null
var curve := 0.0      # rotation de la trajectoire (radians/s) : projectiles qui tournent
var homing := 0.0     # force de guidage vers le joueur (radians/s) : avions de papier...
var harmless := false # faux projectile (leurre) : ne blesse pas
var sprite: Sprite2D = null  # dessin du mob (voir Hazards.shoot)
var look := "aim"    # aim : suit sa trajectoire ; spin : tourne ; still : reste droit
var trail := Color(0, 0, 0, 0)  # couleur de la trainee (transparente : pas de trainee, ex. les mots)
var frames := 1  # images de la bande du sprite (tools/gen_projectiles.py) : il s'anime
var age := 0.0
const FRAME_RATE := 10.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if curve != 0.0:
		direction = direction.rotated(curve * delta)
	if homing > 0.0:
		var target: Node2D = get_tree().get_first_node_in_group("player")
		if target:
			var wanted := (target.global_position - global_position).angle()
			direction = Vector2.from_angle(rotate_toward(direction.angle(), wanted, homing * delta))
	position += direction * speed * delta
	age += delta
	if sprite and frames > 1:
		sprite.frame = int(age * FRAME_RATE) % frames
	if sprite and look == "aim":
		sprite.rotation = direction.angle()
	elif sprite and look == "spin":
		sprite.rotation += 7.0 * delta
	if trail.a > 0.0:
		queue_redraw()

# Trainee : trois carres de pixels qui s'effacent derriere le projectile (sous son dessin), sur la
# grille des pixels d'art.
func _draw() -> void:
	if trail.a <= 0.0:
		return
	for k in [3, 2, 1]:
		var side: float = 8.0 - k * 2.0
		var at: Vector2 = (-direction * k * 7.0 / 2.0).round() * 2.0
		draw_rect(Rect2(at - Vector2.ONE * side / 2.0, Vector2.ONE * side), Color(trail, trail.a * (0.5 - k * 0.12)))

func _on_body_entered(body: Node2D) -> void:
	if body == source:
		return
	if body.has_method("take_damage") and not harmless:
		body.take_damage()
	# Eclat a l'impact : quelques pixels de sa couleur.
	Fx.puff(get_parent(), global_position, trail if trail.a > 0.0 else Color(1, 0.95, 0.85), 8)
	queue_free()
