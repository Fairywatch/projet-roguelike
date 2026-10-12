extends BaseMob

# Battement (mardi, Stress) : un coeur nerveux ; une onde de choc a chaque battement (avec un
# trou pour passer), et les battements accelerent. Variante : deux coeurs qui battent ensemble.
# Cauchemar : le trou est plus etroit.

const RING_COLOR := Color(1, 0.4, 0.5)
const MIN_COOLDOWN := 0.55
const SPEED_UP := 0.85

var twin := false

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mardi/battement.png"

func _on_ready() -> void:
	display_name = "Battement"
	hp = 4
	chase_speed = 45.0
	attack_range = 230.0
	telegraph_duration = 0.45
	attack_duration = 0.1
	cooldown_duration = 1.6
	if alt and not twin:
		spawn_ally("mardi/battement", position + Vector2(0, 90), {"twin": true, "nightmare": nightmare})

func _on_attack_begin() -> void:
	var pulse := create_tween()
	pulse.tween_property(sprite, "scale", sprite.scale * 1.25, 0.06)
	pulse.tween_property(sprite, "scale", sprite.scale, 0.15)
	Hazards.ring(global_position, 170.0, [[randf() * TAU, 0.4 if nightmare else 0.55]], RING_COLOR)
	cooldown_duration = maxf(MIN_COOLDOWN, cooldown_duration * SPEED_UP)
