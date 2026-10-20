extends BaseMob

# Compte a rebours (dimanche, Angoisse) : un chiffre decroit sur son ventre ; a 1, la zone de
# l'explosion apparait autour de lui, et a 0 il explose s'il n'a pas ete detruit avant.
# Variante : en explosant, il fait avancer le decompte des autres. Cauchemar : part de plus bas.

const START := 7
const BLAST_RADIUS := 110.0
const BLAST := Color(1, 0.45, 0.3)

var count := START
var tick := 1.0
var number := Label.new()
var blast_zone: Node2D

func _texture_path() -> String:
	return "res://assets/sprites/mobs/dimanche/compte_a_rebours.png"

func _on_ready() -> void:
	display_name = "Compte à rebours"
	hp = 3
	chase_speed = 50.0
	attack_range = 0.0  # son seul danger : l'explosion
	count = START - (2 if nightmare else 0)
	number.add_theme_font_size_override("font_size", 14)
	number.add_theme_color_override("font_color", Color(0.15, 0.1, 0.15))
	number.position = Vector2(-5, -11)
	add_child(number)
	number.text = str(count)

func advance(steps: int) -> void:
	count = maxi(1, count - steps)
	number.text = str(count)

func _process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	tick -= delta
	if tick > 0.0:
		return
	tick = 1.0
	count -= 1
	number.text = str(count)
	if count == 1:
		blast_zone = Hazards.zone(global_position, BLAST_RADIUS, "damage", 1.0, 0.2, BLAST)
	elif count <= 0:
		if alt:
			for m in get_tree().get_nodes_in_group("mobs"):
				if m != self and m.has_method("advance"):
					m.advance(2)
		_die()

func _physics_process(delta: float) -> void:
	super(delta)
	if is_instance_valid(blast_zone):
		blast_zone.global_position = global_position

func _on_death() -> void:
	if is_instance_valid(blast_zone) and count > 0:  # detruit a temps : pas d'explosion
		blast_zone.queue_free()
