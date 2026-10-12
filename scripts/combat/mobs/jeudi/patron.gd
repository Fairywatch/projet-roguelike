extends BaseMob

# Le Patron sans visage (boss du jeudi) : un costume vide. Il tamponne le sol sous le joueur
# (zone annoncee) d'ou part une onde de choc, et lance des dossiers "REFUSE".
# Variante : trois tampons d'affilee. Cauchemar : ondes plus rapides.

const INK := Color(0.85, 0.2, 0.25)
const PAPER := Color(0.95, 0.92, 0.85)
const WORDS := ["REFUSE", "NON", "PAS ASSEZ", "REFAIS"]

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/jeudi/patron.png"

func _on_ready() -> void:
	display_name = "Le Patron sans visage"
	is_boss = true
	hp = 20
	chase_speed = 45.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 1.4

func _on_attack_begin() -> void:
	cycle += 1
	if cycle % 2 == 0:
		Hazards.fan(self, player.global_position - global_position, 5, 60.0, 155.0, PAPER, WORDS)
		return
	for i in 3 if alt else 1:
		if i > 0 and not await pause(0.5):
			return
		var spot := player.global_position
		Hazards.zone(spot, 60.0, "damage", 0.8, 0.2, INK)
		_shockwave_after(spot, 0.8)

func _shockwave_after(spot: Vector2, delay: float) -> void:
	if await pause(delay):
		var gap := randf() * TAU
		Hazards.ring(spot, 200.0 if nightmare else 160.0, [[gap, 0.5], [gap + PI, 0.5]], INK)
