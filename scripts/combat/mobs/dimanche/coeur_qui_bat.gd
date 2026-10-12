extends BaseMob

# Le Coeur qui Bat (boss du dimanche) : un coeur geant dont les battements accelerent a mesure
# qu'il faiblit ; chaque battement envoie une onde de choc avec un trou, et un battement sur
# quatre en envoie deux. Variante : chaque battement fait aussi pulser des zones autour de lui.
# Cauchemar : trous plus etroits.

const RING_COLOR := Color(1, 0.35, 0.45)
const MIN_COOLDOWN := 0.45

var beats := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/dimanche/coeur_qui_bat.png"

func _on_ready() -> void:
	display_name = "Le Coeur qui Bat"
	is_boss = true
	hp = 24
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.35
	attack_duration = 0.1
	cooldown_duration = 1.4
	set_display_scale(2.4)

func _on_attack_begin() -> void:
	beats += 1
	var pulse := create_tween()
	pulse.tween_property(sprite, "scale", sprite.scale * 1.15, 0.06)
	pulse.tween_property(sprite, "scale", sprite.scale, 0.18)
	var width := 0.4 if nightmare else 0.55
	var gap := randf() * TAU
	Hazards.ring(global_position, 180.0, [[gap, width]], RING_COLOR)
	if beats % 4 == 0 and await pause(0.3):
		Hazards.ring(global_position, 180.0, [[gap + PI, width]], RING_COLOR)
	if alt:
		for i in 4:
			Hazards.zone(global_position + Vector2.from_angle(TAU * i / 4.0 + beats) * 150.0, 46.0, "damage", 0.5, 0.15, RING_COLOR)
	# Plus il faiblit, plus il bat vite.
	cooldown_duration = maxf(MIN_COOLDOWN, 1.4 * float(hp) / max_hp)
