class_name DamageNumber
extends Label

# Chiffre de degats qui saute au-dessus d'un ennemi touche : blanc, ou dore et plus gros pour un
# coup fort (critique, coup final, coup plongeant). Option "Chiffres de degats" des parametres.

const RISE := 18.0
const LIFE := 0.6

var heavy := false

static func spawn(parent: Node, at: Vector2, amount: int, is_heavy: bool = false) -> void:
	if parent == null or amount <= 0 or not Settings.enabled("damage_numbers"):
		return
	var number := DamageNumber.new()
	number.text = str(amount)
	number.heavy = is_heavy
	number.position = at + Vector2(randf_range(-6.0, 6.0), 0.0)
	parent.add_child(number)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	add_theme_font_size_override("font_size", 15 if heavy else 11)
	add_theme_color_override("font_color", Color(1, 0.86, 0.35) if heavy else Color(1, 1, 1))
	add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.08))
	add_theme_constant_override("outline_size", 5)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(40, 20)
	position -= size / 2.0
	pivot_offset = size / 2.0
	scale = Vector2.ONE * (1.9 if heavy else 1.5)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - RISE, LIFE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(LIFE - 0.25)
	tween.chain().tween_callback(queue_free)
