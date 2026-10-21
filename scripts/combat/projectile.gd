extends Area2D

var direction := Vector2.RIGHT
var speed := 220.0
var lifetime := 2.0
var source: Node = null
var curve := 0.0      # rotation de la trajectoire (radians/s) : projectiles qui tournent
var homing := 0.0     # force de guidage vers le joueur (radians/s) : avions de papier...
var harmless := false # faux projectile (leurre) : ne blesse pas

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

func _on_body_entered(body: Node2D) -> void:
	if body == source:
		return
	if body.has_method("take_damage") and not harmless:
		body.take_damage()
	queue_free()
