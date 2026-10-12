extends BaseMob

# Pile de devoirs (mardi, Stress) : lance des feuilles en eventail ; plus elle reste en vie,
# plus elle en lance (les devoirs s'accumulent). Variante : se divise en deux petites piles au
# premier coup recu. Cauchemar : une feuille de plus.

const SHEET_COLOR := Color(0.95, 0.95, 0.88, 0.95)
const SHEETS_PER_SECOND := 1.0 / 6.0  # une feuille de plus toutes les 6 secondes
const MAX_SHEETS := 7

var small := false
var age := 0.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mardi/pile_devoirs.png"

func _on_ready() -> void:
	display_name = "Pile de devoirs"
	hp = 2 if small else 4
	chase_speed = 35.0
	attack_range = 260.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.5
	if small:
		sprite.scale *= 0.7

func _process(delta: float) -> void:
	super(delta)
	age += delta

func _on_attack_begin() -> void:
	var count := mini(MAX_SHEETS, 3 + int(age * SHEETS_PER_SECOND) + (1 if nightmare else 0))
	Hazards.fan(self, player.global_position - global_position, count, 55.0, 150.0, SHEET_COLOR)

func take_hit(damage: int = 1) -> void:
	if alt and not small and state != State.DEAD:
		for side in [-1, 1]:
			spawn_ally("mardi/pile_devoirs", position + Vector2(side * 40, 0), {"small": true, "nightmare": nightmare})
		_die()
		return
	super(damage)
