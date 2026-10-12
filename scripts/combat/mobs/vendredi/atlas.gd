extends BaseMob

# Atlas (boss du vendredi) : un geant qui porte un monde. Il frappe le sol (zone puis onde de
# choc) et fait rouler son monde a travers l'arene, qui rebondit sur les bords.
# Variante : deux mondes a la fois. Cauchemar : le monde roule plus vite.

const SLAM := Color(0.75, 0.6, 0.45)
const WORLD := Color(0.35, 0.6, 0.85)

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/atlas.png"

func _on_ready() -> void:
	display_name = "Atlas"
	is_boss = true
	hp = 22
	chase_speed = 30.0
	attack_range = 2000.0
	telegraph_duration = 0.7
	attack_duration = 0.3
	cooldown_duration = 1.6
	set_display_scale(2.4)

func _on_attack_begin() -> void:
	cycle += 1
	if cycle % 2 == 0:
		var aim := (player.global_position - global_position).normalized()
		for i in 2 if alt else 1:
			Hazards.boulder(global_position + aim * 60.0, aim.rotated(i * 0.6), 260.0 if nightmare else 210.0, 28.0, 5.0, WORLD)
		return
	var spot := player.global_position
	Hazards.zone(spot, 80.0, "damage", 0.8, 0.2, SLAM)
	if await pause(0.8):
		var gap := randf() * TAU
		Hazards.ring(spot, 160.0, [[gap, 0.6], [gap + PI, 0.6]], SLAM)
