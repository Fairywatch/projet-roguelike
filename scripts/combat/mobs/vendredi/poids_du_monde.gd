extends BaseMob

# Le Poids du Monde : boss de fin du vendredi (porter les autres jusqu'a ne plus tenir).
#   Phase 1 : fait de tous ceux qu'il porte ; des Soignants le protegent : il est invulnerable
#             tant qu'il en reste un.
#   Phase 2 : il lache son fardeau ; une vague d'ennemis tombe dans l'arene.
#   Phase 3 : seul et epuise ; tres lent, mais chaque coup est lourd, rare et tres large.

const SLAM := Color(0.6, 0.55, 0.75)
const PHASE_THRESHOLDS := [0.66, 0.33]
const GUARDS := 3
const BURDEN := ["vendredi/fardeau", "vendredi/sangsue", "vendredi/passager", "vendredi/passager", "vendredi/bougie_fondue"]

var phase := 1

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/poids_du_monde.png"

func _on_ready() -> void:
	display_name = "Le Poids du Monde"
	is_boss = true
	hp = 50
	chase_speed = 25.0
	attack_range = 2000.0
	telegraph_duration = 0.8
	attack_duration = 0.3
	cooldown_duration = 1.6
	set_display_scale(2.4)
	for i in GUARDS:
		spawn_ally("vendredi/soignant", position + Vector2.from_angle(TAU * i / GUARDS) * 120.0)

func _guards_alive() -> bool:
	return alive_count("Soignant") > 0

func _process(delta: float) -> void:
	super(delta)
	if phase == 1 and state != State.DEAD:
		invulnerable = _guards_alive()
		sprite.self_modulate = Color(0.75, 1, 0.8) if invulnerable else Color.WHITE

func take_hit(damage: int = 1) -> void:
	super(damage)
	if state == State.DEAD:
		return
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > PHASE_THRESHOLDS[0] else (2 if ratio > PHASE_THRESHOLDS[1] else 3)
	if new_phase > phase:
		phase = new_phase
		Sound.play("boss")
		Fx.flash(sprite, Color(0.9, 0.85, 1), 0.4)
		invulnerable = false
		sprite.self_modulate = Color.WHITE
		if phase == 2:  # il lache son fardeau
			for i in BURDEN.size():
				spawn_ally(BURDEN[i], Vector2(randf_range(120, 780), randf_range(100, 440)))
		else:  # epuise : lent, lourd
			chase_speed = 10.0
			cooldown_duration = 2.6
			telegraph_duration = 1.1

func _on_attack_begin() -> void:
	var spot := player.global_position
	var radius := 150.0 if phase == 3 else 90.0
	Hazards.zone(spot, radius, "damage", 0.9 if phase < 3 else 1.3, 0.25, SLAM)
	if phase == 3 and await pause(1.3):
		var gap := randf() * TAU
		Hazards.ring(spot, 140.0, [[gap, 0.7], [gap + PI, 0.7]], SLAM)
