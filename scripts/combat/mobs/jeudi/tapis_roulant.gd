extends BaseMob

# Le Tapis Roulant (boss du jeudi) : deploie des bandes qui poussent le joueur (on avance sans
# avancer), pendant qu'il tire des boulons. Variante : les bandes poussent vers le tapis, qui mord
# tout ce qui l'approche. Cauchemar : poussee plus forte.

const BAND_TIME := 4.0
const PUSH := 120.0
const BAND := Color(0.55, 0.55, 0.65)
const BOLT := Color(0.8, 0.8, 0.9)

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/jeudi/tapis_roulant.png"

func _on_ready() -> void:
	display_name = "Le Tapis Roulant"
	is_boss = true
	hp = 20
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 1.2

func _on_attack_begin() -> void:
	cycle += 1
	if cycle % 3 == 1:
		var y := player.global_position.y
		var push_dir := Vector2.LEFT if randf() < 0.5 else Vector2.RIGHT
		for x in range(100, 850, 110):
			var spot := Vector2(x, y)
			var toward := (global_position - spot).normalized() if alt else push_dir
			Hazards.zone(Hazards.clamp_to_arena(spot), 60.0, "push", 0.5, BAND_TIME, BAND, toward * PUSH * (1.4 if nightmare else 1.0))
	else:
		Hazards.fan(self, player.global_position - global_position, 4, 40.0, 170.0, BOLT)
	if alt:
		Hazards.zone(global_position, 70.0, "damage", 0.6, 0.2, Color(1, 0.4, 0.4))
