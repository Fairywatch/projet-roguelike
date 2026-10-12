extends BaseMob

# Le Dimanche Soir (boss du dimanche) : une bete crepusculaire. Les bords de l'arene s'assombrissent
# et la resserrent ; assez de degats la font reculer un moment. Elle crache des rayons de soleil
# couchant. Variante : l'arene se resserre plus vite mais par a-coups. Cauchemar : rayons en plus.

const SUNSET := Color(1, 0.6, 0.35)
const BREAK := 0.2  # part des PV a infliger pour faire reculer l'obscurite

var dusk: Node2D
var dusk_hp := 0
var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/dimanche/dimanche_soir.png"

func _on_ready() -> void:
	display_name = "Le Dimanche Soir"
	is_boss = true
	hp = 24
	chase_speed = 35.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 1.4
	set_display_scale(2.4)

func take_hit(damage: int = 1) -> void:
	super(damage)
	if is_instance_valid(dusk) and (state == State.DEAD or dusk_hp - hp >= max_hp * BREAK):
		dusk.stop()

func _on_attack_begin() -> void:
	cycle += 1
	if not is_instance_valid(dusk) and cycle % 2 == 1:
		dusk = Hazards.shrink(30.0 if alt else 16.0, 1.2)
		dusk_hp = hp
		if alt:
			_pause_dusk()
	var aim := (player.global_position - global_position).angle()
	for i in 3 if nightmare else 2:
		var angle := aim + (i - 0.5) * 0.5
		Hazards.beam(global_position, Vector2.from_angle(angle), 22.0, 0.8, 0.3, SUNSET)

# Variante : l'obscurite avance par a-coups (elle avance, s'arrete, recule un peu).
func _pause_dusk() -> void:
	while is_instance_valid(dusk) and not dusk.retracting:
		if not await pause(1.5):
			return
		if is_instance_valid(dusk):
			dusk.speed = 0.0 if dusk.speed > 0.0 else 30.0
