extends BaseMob

# Passager (vendredi) : une petite creature que porte le Fardeau. Rapide et fragile, elle mord.
# Ne fait pas partie du bestiaire tire au hasard : seul le Fardeau en fait apparaitre.

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/passager.png"

func _on_ready() -> void:
	display_name = "Passager"
	hp = 1
	chase_speed = 110.0
	attack_range = 40.0
	telegraph_duration = 0.35
	attack_duration = 0.15
	cooldown_duration = 0.7

func _on_attack_begin() -> void:
	Hazards.zone(global_position + (player.global_position - global_position).normalized() * 22.0, 26.0, "damage", 0.05, 0.12, Color(0.9, 0.7, 0.55))
