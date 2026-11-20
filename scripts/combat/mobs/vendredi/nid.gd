extends BaseMob

# Le Nid (boss du vendredi) : une mere-oiseau qui protege sa nichee. Elle pond des oeufs autour
# d'elle (a casser avant qu'ils n'eclosent en Soignants), lance des plumes en eventail, et fait
# pleuvoir un duvet coupant autour du joueur (zones annoncees). Elle change de nid toutes les
# trois attaques.
# Variante : les oeufs eclosent en Sangsues. Cauchemar : un oeuf de plus par ponte.

const FEATHER := Color(0.75, 0.65, 0.9)
const MAX_EGGS := 4
const DOWN_SPOTS := 5     # zones de duvet par averse
const DOWN_SPREAD := 110.0

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/nid.png"

func _on_ready() -> void:
	display_name = "Le Nid"
	is_boss = true
	hp = 20
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 1.4

func _on_attack_begin() -> void:
	cycle += 1
	var hatch := "vendredi/sangsue" if alt else "vendredi/soignant"
	var brood := alive_count("Œuf") + alive_count("Sangsue de sommeil" if alt else "Soignant")
	if cycle % 3 == 1 and brood < MAX_EGGS:
		for i in 3 if nightmare else 2:
			var spot := position + Vector2.from_angle(TAU * i / 3.0 + randf()) * 110.0
			spawn_ally("vendredi/oeuf", spot, {"hatch": hatch})
		return
	if cycle % 3 == 2:  # averse de duvet : des zones annoncees autour du joueur
		for i in DOWN_SPOTS:
			var spot := player.global_position + Vector2.from_angle(TAU * i / DOWN_SPOTS + randf()) * randf_range(0.0, DOWN_SPREAD)
			Hazards.zone(Hazards.clamp_to_arena(spot), 34.0, "damage", 0.8, 0.3, FEATHER)
		return
	Hazards.fan(self, player.global_position - global_position, 5, 70.0, 160.0, FEATHER)
	relocate(0.8)  # elle s'envole vers un autre perchoir
