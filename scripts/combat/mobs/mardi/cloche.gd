extends BaseMob

# La Cloche (boss du mardi) : sonne trois anneaux concentriques a franchir par leur trou, et
# toutes les trois attaques appelle des Trotteuses. Variante : anneaux sans trou mais plus lents
# (a franchir d'un dash, invincible). Cauchemar : un anneau de plus.

const RING_COLOR := Color(1, 0.85, 0.35)
const MAX_HANDS := 3

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mardi/cloche.png"

func _on_ready() -> void:
	display_name = "La Cloche"
	is_boss = true
	hp = 18
	chase_speed = 40.0
	attack_range = 2000.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.5

func _on_attack_begin() -> void:
	cycle += 1
	if cycle % 3 == 0 and alive_count("Trotteuse") < MAX_HANDS:
		for side in [-1, 1]:
			spawn_ally("mardi/trotteuse", position + Vector2(side * 90, 60))
		return
	var gap := randf() * TAU
	for i in 4 if nightmare else 3:
		if i > 0:
			if not await pause(0.35):
				return
		if alt:
			Hazards.ring(global_position, 110.0, [], RING_COLOR)
		else:
			Hazards.ring(global_position, 160.0, [[gap + i * 0.9, 0.5]], RING_COLOR)
