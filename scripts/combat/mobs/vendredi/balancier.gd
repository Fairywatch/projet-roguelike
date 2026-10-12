extends BaseMob

# Le Balancier (boss du vendredi) : une vieille horloge dont l'enorme pendule balaie l'arene,
# de plus en plus large a chaque attaque ; au bout de sa course tombent des poids (zones).
# Variante : deux pendules decales. Cauchemar : oscille plus vite.

const ROD := Color(0.85, 0.7, 0.4)
const WEIGHT := Color(0.7, 0.6, 0.45)
const SWING_TIME := 4.0

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/balancier.png"

func _on_ready() -> void:
	display_name = "Le Balancier"
	is_boss = true
	hp = 22
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.4
	attack_duration = SWING_TIME + 0.8
	cooldown_duration = 1.0
	_to_top.call_deferred()

func _to_top() -> void:
	global_position = Vector2(450, 80)  # l'horloge est accrochee en haut de l'arene

func _on_attack_begin() -> void:
	cycle += 1
	var swing := minf(0.5 + cycle * 0.12, 1.2)
	var speed := 1.6 * (1.3 if nightmare else 1.0)
	Hazards.sweep(global_position, PI / 2.0, speed, 400.0, 30.0, 0.8, SWING_TIME, ROD, swing)
	if alt:
		Hazards.sweep(global_position, PI / 2.0 + swing * 0.5, -speed, 300.0, 24.0, 0.8, SWING_TIME, ROD, swing)
	for side in [-1, 1]:  # poids qui tombent au bout de la course
		var end := global_position + Vector2.from_angle(PI / 2.0 + side * swing) * 380.0
		Hazards.zone(Hazards.clamp_to_arena(end), 50.0, "damage", 1.2, 0.3, WEIGHT)
