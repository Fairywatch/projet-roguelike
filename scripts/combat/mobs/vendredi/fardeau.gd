extends BaseMob

# Fardeau (vendredi, Epuisement) : une grosse creature qui porte des petits sur son dos. Chaque
# coup recu fait tomber un passager, qui devient un ennemi. Elle frappe le sol devant elle.
# Variante : elle lance ses passagers sur le joueur (point de chute annonce).
# Cauchemar : un passager de plus.

const SLAM := Color(0.8, 0.7, 0.6)

var passengers := 3

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/fardeau.png"

func _on_ready() -> void:
	display_name = "Fardeau"
	hp = 6
	chase_speed = 35.0
	attack_range = 80.0 if not alt else 300.0
	telegraph_duration = 0.7
	attack_duration = 0.2
	cooldown_duration = 1.4
	if nightmare:
		passengers += 1

func take_hit(damage: int = 1) -> void:
	super(damage)
	if state != State.DEAD and passengers > 0 and not alt:
		passengers -= 1
		spawn_ally("vendredi/passager", position + Vector2(randf_range(-30, 30), -30))

func _on_telegraph_begin() -> void:
	if alt and passengers > 0:
		Hazards.zone(player.global_position, 40.0, "damage", telegraph_duration + 0.4, 0.15, SLAM)
	else:
		Hazards.zone(global_position + (player.global_position - global_position).normalized() * 50.0, 56.0, "damage", telegraph_duration, 0.2, SLAM)

func _on_attack_begin() -> void:
	if alt and passengers > 0:
		passengers -= 1
		var landing := player.global_position
		if await pause(0.4):
			spawn_ally("vendredi/passager", landing)
