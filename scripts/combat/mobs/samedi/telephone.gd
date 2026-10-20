extends BaseMob

# Le Telephone Muet (boss du samedi) : il sonne en ondes de choc. Juste apres chaque sonnerie,
# il faut "decrocher" : pendant un court instant (signale par un "!"), il prend triple degats.
# Variante : sonne quatre fois d'affilee, plus vite. Cauchemar : ondes plus rapides.

const RING_COLOR := Color(0.9, 0.9, 1.0)
const ANSWER_TIME := 1.3

var answer_window := 0.0
var mark := Label.new()

func _texture_path() -> String:
	return "res://assets/sprites/mobs/samedi/telephone.png"

func _on_ready() -> void:
	display_name = "Le Téléphone Muet"
	is_boss = true
	hp = 22
	chase_speed = 30.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 1.6
	set_display_scale(2.4)
	mark.text = "!"
	mark.add_theme_font_size_override("font_size", 20)
	mark.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	mark.position = Vector2(-5, -62)
	mark.visible = false
	add_child(mark)

func _process(delta: float) -> void:
	super(delta)
	answer_window = maxf(0.0, answer_window - delta)
	mark.visible = answer_window > 0.0

func take_hit(damage: int = 1) -> void:
	super(damage * (3 if answer_window > 0.0 else 1))

func _on_attack_begin() -> void:
	var rings := 4 if alt else 2
	for i in rings:
		if i > 0 and not await pause(0.5 if alt else 0.7):
			return
		var gap := randf() * TAU
		Hazards.ring(global_position, 200.0 if nightmare else 160.0, [[gap, 0.55], [gap + PI, 0.55]], RING_COLOR)
	answer_window = ANSWER_TIME
