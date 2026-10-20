extends BaseMob

# Le Reveil Grincheux (boss du lundi) : sonne des anneaux d'onde de choc avec des trous pour
# passer ; toutes les quatre attaques il fait "snooze" : il s'endort et prend double degats.
# Variante : lance une couronne de cloches au lieu des anneaux. Cauchemar : un anneau de plus.

const RING_SPEED := 150.0
const RING_COLOR := Color(1, 0.8, 0.45)
const GAP_WIDTH := 0.42  # demi-largeur du trou, en radians
const SNOOZE_TIME := 2.5

var rings := 0
var snoozing := false
var zzz := Label.new()

func _texture_path() -> String:
	return "res://assets/sprites/mobs/lundi/reveil_grincheux.png"

func _on_ready() -> void:
	display_name = "Le Réveil Grincheux"
	is_boss = true
	hp = 16
	chase_speed = 50.0
	attack_range = 2000.0
	telegraph_duration = 0.7
	attack_duration = 0.2
	cooldown_duration = 1.2
	zzz.text = "Zzz"
	zzz.add_theme_font_size_override("font_size", 14)
	zzz.position = Vector2(14, -54)
	zzz.visible = false
	add_child(zzz)

func _on_attack_begin() -> void:
	rings += 1
	if rings % 4 == 0:
		_snooze()
		return
	if alt:
		Hazards.radial(self, 16 if nightmare else 12, 140.0, RING_COLOR, randf() * TAU)
		return
	for i in 3 if nightmare else 2:
		if i > 0:
			if not await pause(0.45):
				return
		var gap := randf() * TAU
		Hazards.ring(global_position, RING_SPEED, [[gap, GAP_WIDTH], [gap + PI, GAP_WIDTH]], RING_COLOR)

func _snooze() -> void:
	snoozing = true
	zzz.visible = true
	stun(SNOOZE_TIME)
	await pause(SNOOZE_TIME)
	snoozing = false
	zzz.visible = false

func take_hit(damage: int = 1) -> void:
	super(damage * (2 if snoozing else 1))
