extends BaseMob

# Oeuf (vendredi) : pondu par le Nid. Immobile ; s'il n'est pas casse a temps, il eclot en
# Soignant (ou en Sangsue pour la variante du Nid). Ne fait pas partie du bestiaire tire au hasard.

const HATCH_TIME := 5.0

var hatch := "vendredi/soignant"
var timer := HATCH_TIME

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/oeuf.png"

func _on_ready() -> void:
	display_name = "Oeuf"
	hp = 2
	attack_range = 0.0
	chase_speed = 0.0

func _process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	timer -= delta
	sprite.offset.x = randf_range(-1, 1) if timer < 1.5 else 0.0  # tremble avant d'eclore
	if timer <= 0.0:
		spawn_ally(hatch, position)
		state = State.DEAD
		Fx.puff(get_parent(), global_position, Color(0.95, 0.9, 0.8), 12)
		queue_free()
