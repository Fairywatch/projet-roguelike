extends BaseMob

# Le Tableau Noir (boss du mardi) : dessine a la craie des motifs au sol (lignes, croix, damier),
# qui frappent apres un delai de plus en plus court. Variante : souffle aussi de la poussiere de
# craie en eventail. Cauchemar : delai plus court.

const CHALK := Color(0.92, 0.95, 0.9)
const CELL := 100.0
const RADIUS := 40.0

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mardi/tableau_noir.png"

func _on_ready() -> void:
	display_name = "Le Tableau Noir"
	is_boss = true
	hp = 18
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.4
	cooldown_duration = 1.4

func _arm_delay() -> float:
	return maxf(0.55, 1.3 - cycle * 0.07 - (0.2 if nightmare else 0.0))

func _on_attack_begin() -> void:
	cycle += 1
	var points := []
	var target := player.global_position
	match cycle % 3:
		0:  # trois lignes horizontales, dont une sur le joueur
			for row in [target.y - CELL * 1.5, target.y, target.y + CELL * 1.5]:
				for x in range(100, 850, int(CELL)):
					points.append(Vector2(x, row))
		1:  # croix centree sur le joueur
			for x in range(100, 850, int(CELL)):
				points.append(Vector2(x, target.y))
			for y in range(100, 500, int(CELL)):
				points.append(Vector2(target.x, y))
		2:  # damier
			for y in range(100, 500, int(CELL)):
				for x in range(100, 850, int(CELL)):
					if (int(x / CELL) + int(y / CELL) + cycle) % 2 == 0:
						points.append(Vector2(x, y))
	for point in points:
		Hazards.zone(Hazards.clamp_to_arena(point), RADIUS, "damage", _arm_delay(), 0.25, CHALK)
	if alt:
		Hazards.fan(self, target - global_position, 5, 70.0, 150.0, CHALK)
