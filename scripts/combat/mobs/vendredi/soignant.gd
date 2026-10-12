extends BaseMob

# Soignant (vendredi, Epuisement) : fuit le joueur et soigne les autres ennemis proches (anneau
# vert). Variante : relie deux ennemis par un lien ; ils sont invulnerables tant que le Soignant
# vit. Cauchemar : soigne plus.

const KEEP_AWAY := 220.0
const FLEE_SPEED := 80.0
const HEAL_EVERY := 3.0
const HEAL_RANGE := 220.0
const HEAL := 2

var heal_timer := HEAL_EVERY
var linked: Array = []
var ring_t := 0.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/soignant.png"

func _on_ready() -> void:
	display_name = "Soignant"
	hp = 3
	attack_range = 0.0

func _allies() -> Array:
	return get_tree().get_nodes_in_group("mobs").filter(func(m): return m != self and m.state != State.DEAD and m.display_name != display_name)

func _physics_process(delta: float) -> void:
	if state != State.CHASE or player == null:
		return
	var away := global_position - player.global_position
	velocity = away.normalized() * FLEE_SPEED if away.length() < KEEP_AWAY else Vector2.ZERO
	move_and_slide()
	global_position = Hazards.clamp_to_arena(global_position)
	if alt:
		linked = linked.filter(func(m): return is_instance_valid(m) and m.state != State.DEAD)
		if linked.size() < 2:
			for m in _allies():
				if m not in linked and linked.size() < 2:
					linked.append(m)
		for m in linked:
			m.invulnerable = true
		return
	heal_timer -= delta
	if heal_timer <= 0.0:
		heal_timer = HEAL_EVERY
		ring_t = 0.4
		for m in _allies():
			if m.global_position.distance_to(global_position) < HEAL_RANGE:
				m.hp = mini(m.max_hp, m.hp + HEAL * (2 if nightmare else 1))
				Fx.flash(m.sprite, Color(0.5, 1, 0.6), 0.2)

func _process(delta: float) -> void:
	super(delta)
	ring_t = maxf(0.0, ring_t - delta)

func _draw() -> void:
	super()
	if ring_t > 0.0:
		draw_arc(Vector2.ZERO, HEAL_RANGE * (1.0 - ring_t / 0.4), 0.0, TAU, 40, Color(0.5, 1, 0.6, ring_t), 3.0)
	for m in linked:
		if is_instance_valid(m):
			draw_line(Vector2.ZERO, m.global_position - global_position, Color(0.5, 1, 0.7, 0.6), 2.0)

func _on_death() -> void:
	for m in linked:  # le lien se rompt
		if is_instance_valid(m):
			m.invulnerable = false
