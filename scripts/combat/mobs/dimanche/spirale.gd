extends BaseMob

# Spirale (dimanche, Angoisse) : un tourbillon qui attire le joueur pendant que des orbes
# tournent autour de lui (les toucher blesse). Variante : deux spirales qui tournent en sens
# contraire. Cauchemar : orbes plus nombreux.

const PULL_RANGE := 280.0
const PULL_SPEED := 80.0
const ORBIT_RADIUS := 70.0
const ORB_RADIUS := 9.0
const ORB_COLOR := Color(0.7, 0.5, 1.0)

var spin_dir := 1.0
var twin := false
var orbit := 0.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/dimanche/spirale.png"

func _on_ready() -> void:
	display_name = "Spirale"
	hp = 4
	chase_speed = 30.0
	attack_range = 0.0  # attire et fait tourner ses orbes en permanence
	if alt and not twin:
		spawn_ally("dimanche/spirale", position + Vector2(200, 0), {"twin": true, "spin_dir": -1.0, "nightmare": nightmare})

func _orb_count() -> int:
	return 6 if nightmare else 4

func _orbs() -> Array:
	var positions := []
	for i in _orb_count():
		positions.append(Vector2.from_angle(orbit + TAU * i / _orb_count()) * ORBIT_RADIUS)
	return positions

func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	orbit += 2.0 * spin_dir * delta
	sprite.rotation += 3.0 * spin_dir * delta
	var p := Hazards.player()
	if p == null or state != State.CHASE:
		return
	var to_me := global_position - p.global_position
	if to_me.length() < PULL_RANGE:
		p.add_external_velocity(to_me.normalized() * PULL_SPEED)
	for orb in _orbs():
		if (global_position + orb).distance_to(p.global_position) < ORB_RADIUS + 12.0:
			p.take_damage()

func _draw() -> void:
	super()
	if state != State.DEAD:
		for orb in _orbs():
			draw_circle(orb, ORB_RADIUS, ORB_COLOR)
