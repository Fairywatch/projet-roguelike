extends BaseMob

# La Liste du Lendemain (boss du dimanche) : un parchemin de taches qui fait pleuvoir ses mots
# du haut de l'arene, en rangs serres avec des trous ou se glisser. Variante : la pluie tombe en
# diagonale. Cauchemar : rangs plus serres.

const WORDS := ["LUNDI", "REUNION", "FACTURES", "REVEIL", "A FAIRE", "EN RETARD"]
const INK := Color(0.95, 0.9, 0.8)
const RAIN_SPEED := 130.0

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/dimanche/liste_lendemain.png"

func _on_ready() -> void:
	display_name = "La Liste du Lendemain"
	is_boss = true
	hp = 22
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.4
	attack_duration = 0.2
	cooldown_duration = 1.5
	set_display_scale(2.4)

func _on_attack_begin() -> void:
	cycle += 1
	var spacing := 70.0 if nightmare else 90.0
	var gap := randf_range(100.0, 800.0)  # le trou ou se glisser
	var direction := Vector2(0.45, 1.0).normalized() if alt else Vector2.DOWN
	var x := 70.0
	var i := 0
	while x < 860.0:
		if absf(x - gap) > 70.0:
			var word := Hazards.shoot(self, direction, RAIN_SPEED, INK, WORDS[(i + cycle) % WORDS.size()], 5.0)
			word.global_position = Vector2(x - (200.0 if alt else 0.0), 40.0)
		x += spacing
		i += 1
