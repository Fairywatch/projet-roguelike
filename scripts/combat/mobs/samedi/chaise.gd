extends BaseMob

# Chaise vide (samedi, Solitude) : une chaise qui glisse toute seule ; elle tremble (annonce),
# puis charge en tournant a travers l'arene. Variante : une rangee de chaises qui chargent en
# formation, cote a cote. Cauchemar : charge plus vite.

const CHARGE_SPEED := 400.0
const HIT_RANGE := 30.0

var charge_dir := Vector2.ZERO
var follower := false

func _texture_path() -> String:
	return "res://assets/sprites/mobs/samedi/chaise.png"

func _on_ready() -> void:
	display_name = "Chaise vide"
	hp = 3
	chase_speed = 40.0
	attack_range = 280.0
	telegraph_duration = 0.6
	attack_duration = 0.6
	cooldown_duration = 1.3
	if alt and not follower:
		for side in [-1, 1]:
			spawn_ally("samedi/chaise", position + Vector2(0, side * 70), {"follower": true, "nightmare": nightmare})

func _on_telegraph_begin() -> void:
	charge_dir = (player.global_position - global_position).normalized()
	Hazards.beam(global_position, charge_dir, 6.0, telegraph_duration, 0.0, Color(0.85, 0.65, 0.45))

func _physics_process(delta: float) -> void:
	if state != State.ATTACK:
		sprite.rotation = 0.0
		super(delta)
		return
	velocity = charge_dir * CHARGE_SPEED * (1.25 if nightmare else 1.0)
	move_and_slide()
	sprite.rotation += 14.0 * delta
	var p := Hazards.player()
	if p and p.global_position.distance_to(global_position) < HIT_RANGE:
		p.take_damage()
