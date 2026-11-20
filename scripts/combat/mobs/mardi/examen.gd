extends BaseMob

# L'Examen : boss de fin du mardi (la peur de decevoir). La copie tourne ses pages : il change
# de place dans la salle toutes les trois attaques.
#   Phase 1 : les questions tombent. En boucle : une salve de lettres en eventail ; le QCM (la salle
#             coupee en quatre couloirs A B C D, trois sont frappes, un seul est la bonne reponse) ;
#             une couronne de lettres.
#   Phase 2 : le compte a rebours ; l'arene se resserre tant qu'on ne lui inflige pas assez de
#             degats, puis se rouvre un moment avant de recommencer. Salves et couronnes alternent.
#   Phase 3 : la note ; une pluie d'encre rouge (zones), une salve visee, et toutes les trois
#             attaques un grand coup de tampon sur le joueur.

const LETTERS := ["A", "B", "C", "D", "?"]
const LETTER_COLOR := Color(0.25, 0.3, 0.6)
const INK := Color(0.85, 0.1, 0.2)
const PHASE_THRESHOLDS := [0.66, 0.33]
const SHRINK_BREAK := 0.15  # part des PV max a infliger pour faire reculer le compte a rebours
const LANES := 4           # QCM : couloirs verticaux A B C D
const QCM_TELEGRAPH := 1.0
const MOVE_EVERY := 3

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
			match cycle % 3:
				1:
					Hazards.fan(self, direction, 5, 70.0, 165.0, LETTER_COLOR, LETTERS)
				2:
					_qcm()
				0:
					Hazards.radial(self, 12, 110.0, LETTER_COLOR, randf() * TAU, LETTERS)
		2:
			if not is_instance_valid(countdown):
				countdown = Hazards.shrink(20.0, 1.2)
				countdown_hp = hp
			if cycle % 2 == 0:
				Hazards.radial(self, 10, 105.0, LETTER_COLOR, randf() * TAU, LETTERS)
			else:
				Hazards.fan(self, direction, 5, 55.0, 150.0, LETTER_COLOR, LETTERS)
		3:
			for i in 8:
				var spot := Hazards.clamp_to_arena(Vector2(randf_range(80, 820), randf_range(80, 460)))
				Hazards.zone(spot, 40.0, "damage", 0.9, 0.3, INK)
			if cycle % 3 == 0:
				Hazards.zone(player.global_position, 120.0, "damage", 1.3, 0.3, INK)
			else:
				Hazards.fan(self, direction, 3, 30.0, 170.0, INK, LETTERS)
	if cycle % MOVE_EVERY == 0 and phase != 2:  # en phase 2, l'arene se resserre deja
		vanish_to()

# QCM : trois couloirs sur quatre sont frappes de haut en bas ; une seule bonne reponse. Les
# rayons sont un peu plus etroits que les couloirs (le rayon touche a width / 2 + 10) : le bon
# couloir est sur sur toute sa largeur.
func _qcm() -> void:
	var lane_width := Hazards.ARENA.size.x / LANES
	var safe := randi() % LANES
	for lane in LANES:
		if lane == safe:
			continue
		var x := Hazards.ARENA.position.x + lane_width * (lane + 0.5)
		Hazards.beam(Vector2(x, Hazards.ARENA.position.y - 10.0), Vector2.DOWN, lane_width - 36.0, QCM_TELEGRAPH, 0.35, LETTER_COLOR)
