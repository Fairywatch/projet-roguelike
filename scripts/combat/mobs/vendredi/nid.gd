extends BaseMob

# Le Nid (boss du vendredi) : une mere-oiseau qui protege sa nichee. Elle pond des oeufs autour
# d'elle (a casser avant qu'ils n'eclosent en Soignants) et lance des plumes.
# Variante : les oeufs eclosent en Sangsues. Cauchemar : un oeuf de plus par ponte.

const FEATHER := Color(0.75, 0.65, 0.9)
const MAX_EGGS := 4

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
	if cycle % 3 == 1 and alive_count("Œuf") < MAX_EGGS:
		var hatch := "vendredi/sangsue" if alt else "vendredi/soignant"
		for i in 3 if nightmare else 2:
			var spot := position + Vector2.from_angle(TAU * i / 3.0 + randf()) * 110.0
			spawn_ally("vendredi/oeuf", spot, {"hatch": hatch})
		return
	Hazards.fan(self, player.global_position - global_position, 5, 70.0, 160.0, FEATHER)
