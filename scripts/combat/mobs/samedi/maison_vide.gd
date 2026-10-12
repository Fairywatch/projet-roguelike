extends BaseMob

# La Maison Vide (boss du samedi) : ses fenetres tirent des rayons (annonces) et sa porte laisse
# sortir des Silhouettes. Variante : la fenetre allumee tire une couronne de souvenirs.
# Cauchemar : un rayon de plus.

const LIGHT := Color(1, 0.88, 0.55)
const MAX_GHOSTS := 2

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/samedi/maison_vide.png"

func _on_ready() -> void:
	display_name = "La Maison Vide"
	is_boss = true
	hp = 22
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.4
	attack_duration = 0.3
	cooldown_duration = 1.3
	set_display_scale(2.4)

func _on_attack_begin() -> void:
	cycle += 1
	if cycle % 3 == 0 and alive_count("Silhouette") < MAX_GHOSTS:
		spawn_ally("samedi/silhouette", position + Vector2(20, 70))
		return
	var aim := (player.global_position - global_position).angle()
	var count := 3 if nightmare else 2
	for i in count:
		var angle := aim + (i - (count - 1) / 2.0) * 0.35
		Hazards.beam(global_position, Vector2.from_angle(angle), 22.0, 0.9, 0.3, LIGHT)
	if alt:
		Hazards.radial(self, 10, 110.0, LIGHT, randf() * TAU)
