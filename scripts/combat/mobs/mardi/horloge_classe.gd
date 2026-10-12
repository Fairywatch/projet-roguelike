extends BaseMob

# L'Horloge de Classe (boss du mardi) : ses deux aiguilles balaient l'arene comme des bras
# rotatifs (trait pale avant de tourner), un peu plus vite a chaque attaque.
# Variante : les aiguilles tournent en sens contraire. Cauchemar : tournent plus vite.

const HAND_COLOR := Color(0.9, 0.3, 0.3)
const SWEEP_TIME := 3.0

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mardi/horloge_classe.png"

func _on_ready() -> void:
	display_name = "L'Horloge de Classe"
	is_boss = true
	hp = 18
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.4
	attack_duration = SWEEP_TIME + 0.8
	cooldown_duration = 1.0

func _on_attack_begin() -> void:
	cycle += 1
	var speed := minf(1.0 + cycle * 0.12, 2.2) * (1.25 if nightmare else 1.0)
	var start := (player.global_position - global_position).angle() + PI * 0.6
	Hazards.sweep(global_position, start, speed, 560.0, 18.0, 0.8, SWEEP_TIME, HAND_COLOR)
	Hazards.sweep(global_position, start + PI, speed * (-0.7 if alt else 0.7), 320.0, 22.0, 0.8, SWEEP_TIME, HAND_COLOR)
