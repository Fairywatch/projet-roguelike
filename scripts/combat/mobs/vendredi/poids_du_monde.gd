extends BaseMob

# Le Poids du Monde : boss de fin du vendredi (porter les autres jusqu'a ne plus tenir).
#   Il ecrase le sol sous le joueur, puis frappe une seconde fois la ou celui-ci fuyait ; toutes
#   les trois attaques, ses fardeaux roulent vers le joueur (rochers qui rebondissent).
#   Phase 1 : fait de tous ceux qu'il porte ; des Soignants le protegent : il est invulnerable
#             tant qu'il en reste un.
#   Phase 2 : il lache son fardeau ; une vague d'ennemis tombe dans l'arene.
#   Phase 3 : seul et epuise ; tres lent, mais chaque coup est lourd, rare et tres large, suivi
#             d'une onde a trous ; les fardeaux roulent une attaque sur deux, par trois.

const SLAM := Color(0.6, 0.55, 0.75)
const PHASE_THRESHOLDS := [0.66, 0.33]
const GUARDS := 2
const BURDEN := ["vendredi/fardeau", "vendredi/sangsue", "vendredi/passager"]

var phase := 1
var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/poids_du_monde.png"

func _on_ready() -> void:
	display_name = "Le Poids du Monde"
	is_boss = true
	hp = 44
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
	cycle += 1
	var spot := player.global_position
	var radius := 150.0 if phase == 3 else 90.0
	Hazards.zone(spot, radius, "damage", 0.9 if phase < 3 else 1.3, 0.25, SLAM)
	if cycle % (2 if phase == 3 else 3) == 0:
		_roll_burdens()
	if phase == 3:
		if await pause(1.3):
			var gap := randf() * TAU
			Hazards.ring(spot, 140.0, [[gap, 0.7], [gap + PI, 0.7]], SLAM)
	elif await pause(0.55) and player:
		# Le second coup tombe la ou le joueur fuyait.
		var moving: Variant = player.get("velocity")
		var ahead: Vector2 = player.global_position + (moving if moving is Vector2 else Vector2.ZERO) * 0.45
		Hazards.zone(Hazards.clamp_to_arena(ahead), 70.0, "damage", 0.75, 0.25, SLAM)

# Les fardeaux roulent : des rochers qui partent vers le joueur et rebondissent sur les murs.
func _roll_burdens() -> void:
	var aim := player.global_position - global_position
	for offset in ([-0.35, 0.35] if phase < 3 else [-0.5, 0.0, 0.5]):
		Hazards.boulder(global_position, aim.rotated(offset), 150.0, 22.0, 5.0, SLAM)
