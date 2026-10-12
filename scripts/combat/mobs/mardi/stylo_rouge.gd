extends BaseMob

# Stylo rouge (mardi, Stress) : tourne autour du joueur en laissant une traine d'encre rouge qui
# blesse apres un court instant. Variante : trace aussi un grand X sur le joueur (deux rayons
# annonces). Cauchemar : tourne plus vite.

const ORBIT_RADIUS := 130.0
const ORBIT_SPEED := 1.5  # radians/s
const MOVE_SPEED := 230.0
const TRAIL_EVERY := 0.18
const X_EVERY := 3.2
const INK := Color(0.85, 0.1, 0.2)

var angle := randf() * TAU
var trail_timer := 0.0
var x_timer := X_EVERY

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mardi/stylo_rouge.png"

func _on_ready() -> void:
	display_name = "Stylo rouge"
	hp = 3

func _physics_process(delta: float) -> void:
	if state != State.CHASE or player == null:  # mort ou etourdi
		return
	angle += ORBIT_SPEED * delta * (1.4 if nightmare else 1.0)
	var target := Hazards.clamp_to_arena(player.global_position + Vector2.from_angle(angle) * ORBIT_RADIUS)
	velocity = (target - global_position).limit_length(MOVE_SPEED)
	move_and_slide()
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = TRAIL_EVERY
		Hazards.zone(global_position, 16.0, "damage", 0.35, 1.6, INK)
	if alt:
		x_timer -= delta
		if x_timer <= 0.0:
			x_timer = X_EVERY
			var cross := player.global_position
			for direction in [Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]:
				Hazards.beam(cross - direction * 300.0, direction, 22.0, 0.9, 0.3, INK)
