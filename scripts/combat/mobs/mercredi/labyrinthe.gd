extends BaseMob

# Le Labyrinthe (boss du mercredi) : fait surgir des murs qui decoupent l'arene en couloirs,
# puis tire des rayons le long du couloir du joueur (annonces). Variante : lance des pierres a
# travers les ouvertures. Cauchemar : murs avec des ouvertures plus etroites.

const WALL_TIME := 7.0
const WALL_COLOR := Color(0.36, 0.42, 0.38)
const BEAM_COLOR := Color(0.55, 1, 0.65)

var walls_until := 0.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mercredi/labyrinthe.png"

func _on_ready() -> void:
	display_name = "Le Labyrinthe"
	is_boss = true
	hp = 18
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.3
	cooldown_duration = 1.4

func _on_attack_begin() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now >= walls_until:
		walls_until = now + WALL_TIME + 0.6
		_raise_walls()
		return
	var p := player.global_position
	Hazards.beam(Vector2(50, p.y), Vector2.RIGHT, 26.0, 0.9, 0.3, BEAM_COLOR)
	if alt:
		Hazards.fan(self, p - global_position, 5, 80.0, 150.0, WALL_COLOR.lightened(0.4))

# Deux murs horizontaux, chacun avec une ouverture a un endroit au hasard.
func _raise_walls() -> void:
	var gap := 110.0 if nightmare else 150.0
	for y in [190.0, 350.0]:
		var opening := randf_range(150.0, 750.0)
		Hazards.wall(Rect2(Vector2(50, y - 10), Vector2(opening - gap / 2.0 - 50, 20)), WALL_TIME, WALL_COLOR)
		Hazards.wall(Rect2(Vector2(opening + gap / 2.0, y - 10), Vector2(850 - opening - gap / 2.0, 20)), WALL_TIME, WALL_COLOR)
