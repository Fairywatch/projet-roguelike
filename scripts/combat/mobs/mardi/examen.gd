extends BaseMob

# L'Examen : boss de fin du mardi (la peur de decevoir).
#   Phase 1 : les questions tombent en lettres-projectiles.
#   Phase 2 : le compte a rebours ; l'arene se resserre tant qu'on ne lui inflige pas assez de
#             degats, puis se rouvre un moment avant de recommencer.
#   Phase 3 : la note ; une pluie d'encre rouge (zones) et, toutes les quatre attaques, un grand
#             coup de tampon sur le joueur.

const LETTERS := ["A", "B", "C", "D", "?"]
const LETTER_COLOR := Color(0.25, 0.3, 0.6)
const INK := Color(0.85, 0.1, 0.2)
const PHASE_THRESHOLDS := [0.66, 0.33]
const SHRINK_BREAK := 0.15  # part des PV max a infliger pour faire reculer le compte a rebours

var phase := 1
var cycle := 0
var countdown: Node2D
var countdown_hp := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mardi/examen.png"

func _on_ready() -> void:
	display_name = "L'Examen"
	is_boss = true
	hp = 44
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 1.1
	auto_frames = false
	sprite.frame = 0

func take_hit(damage: int = 1) -> void:
	super(damage)
	if state == State.DEAD:
		if is_instance_valid(countdown):
			countdown.stop()
		return
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > PHASE_THRESHOLDS[0] else (2 if ratio > PHASE_THRESHOLDS[1] else 3)
	if new_phase > phase:
		phase = new_phase
		Sound.play("boss")
		Fx.flash(sprite, Color(1, 0.9, 0.9), 0.4)
		sprite.frame = 1  # l'oeil s'ouvre
		if phase == 3 and is_instance_valid(countdown):
			countdown.stop()
	if phase == 2 and is_instance_valid(countdown) and countdown_hp - hp >= max_hp * SHRINK_BREAK:
		countdown.stop()  # assez de degats : le temps recule

func _on_attack_begin() -> void:
	cycle += 1
	var direction := player.global_position - global_position
	match phase:
		1:
			Hazards.fan(self, direction, 5, 70.0, 165.0, LETTER_COLOR, LETTERS)
			if cycle % 3 == 0:
				Hazards.radial(self, 10, 110.0, LETTER_COLOR, randf() * TAU, LETTERS)
		2:
			if not is_instance_valid(countdown):
				countdown = Hazards.shrink(20.0, 1.2)
				countdown_hp = hp
			Hazards.fan(self, direction, 3, 40.0, 140.0, LETTER_COLOR, LETTERS)
		3:
			for i in 8:
				var spot := Hazards.clamp_to_arena(Vector2(randf_range(80, 820), randf_range(80, 460)))
				Hazards.zone(spot, 40.0, "damage", 0.9, 0.3, INK)
			if cycle % 4 == 0:
				Hazards.zone(player.global_position, 120.0, "damage", 1.3, 0.3, INK)
