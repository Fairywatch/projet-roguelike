extends BaseMob

# La Derniere Nuit : boss de fin du dimanche, et du jeu (la peur de la fin).
#   Phase 1 : elle reprend les attaques des boss de fin de toute la semaine, l'une apres l'autre.
#   Phase 2 : l'arene se resserre dans le noir.
#   Phase 3 : impossible a vaincre ; il faut tenir jusqu'a l'aube. Quand le jour se leve, elle se
#             dissout (en echo a la fin du recit : "il a cesse de lutter contre l'aube").

const PHASE_THRESHOLDS := [0.66, 0.33]
const DAWN_TIME := 30.0
const WORDS := ["CHUT", "TAIS-TOI", "PLUS TARD"]
const LETTERS := ["A", "B", "C", "?"]
const NIGHT := Color(0.6, 0.5, 0.9)
const LIGHTNING := Color(1, 0.95, 0.5)
const SOFT := Color(1, 0.88, 0.8, 0.9)

var phase := 1
var cycle := 0
var dark: Node2D
var dawn := DAWN_TIME

func _texture_path() -> String:
	return "res://assets/sprites/mobs/dimanche/derniere_nuit.png"

func _on_ready() -> void:
	display_name = "La Derniere Nuit"
	is_boss = true
	hp = 54
	chase_speed = 30.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 1.1
	set_display_scale(2.4)

func take_hit(damage: int = 1) -> void:
	super(damage)
	if state == State.DEAD:
		return
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > PHASE_THRESHOLDS[0] else (2 if ratio > PHASE_THRESHOLDS[1] else 3)
	if new_phase > phase:
		phase = new_phase
		Sound.play("boss")
		Fx.flash(sprite, Color(0.8, 0.7, 1), 0.4)
		if phase == 2:
			dark = Hazards.shrink(14.0, 1.2)
		else:  # plus rien a frapper : seulement tenir
			invulnerable = true
			cooldown_duration = 0.8

func _process(delta: float) -> void:
	super(delta)
	if phase != 3 or state == State.DEAD:
		return
	dawn -= delta
	display_name = "Tenir jusqu'a l'aube : %d s" % ceili(maxf(dawn, 0.0))
	sprite.self_modulate.a = clampf(dawn / DAWN_TIME, 0.2, 1.0)  # la nuit palit
	if dawn <= 0.0:
		if is_instance_valid(dark):
			dark.stop()
		invulnerable = false
		_die()

func _on_death() -> void:
	if is_instance_valid(dark):
		dark.stop()

func _on_attack_begin() -> void:
	cycle += 1
	var aim := player.global_position - global_position
	match cycle % 5:  # lundi, mardi, jeudi, vendredi, samedi
		0:
			Hazards.fan(self, aim, 5, 60.0, 160.0, NIGHT, WORDS)
		1:
			Hazards.radial(self, 12, 120.0, NIGHT, randf() * TAU, LETTERS)
		2:
			for i in 6:
				var spot := global_position.lerp(player.global_position, (i + 1) / 6.0)
				Hazards.zone(Hazards.clamp_to_arena(spot), 32.0, "damage", 0.6 + i * 0.08, 0.15, LIGHTNING)
		3:
			Hazards.zone(player.global_position, 100.0, "damage", 1.0, 0.2, NIGHT)
		4:
			for i in 6:
				Hazards.shoot(self, aim.rotated(randf_range(-0.6, 0.6)), 100.0, SOFT)
	if phase == 3:  # l'aube approche : la nuit s'acharne
		var gap := randf() * TAU
		Hazards.ring(global_position, 150.0, [[gap, 0.6], [gap + PI, 0.6]], NIGHT)
