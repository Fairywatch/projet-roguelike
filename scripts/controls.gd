class_name Controls

# Touches du jeu. Codes physiques (position sur le clavier) : sur un AZERTY, KEY_W/KEY_A
# sont les touches Z/Q, donc ZQSD en AZERTY et WASD en QWERTY. Les fleches marchent aussi.

const ATTACK := KEY_J
const DASH := KEY_K
const ACTIVE := KEY_L
const INTERACT := KEY_E

static func move_vector() -> Vector2:
	var v := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left") + _held(KEY_D) - _held(KEY_A),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up") + _held(KEY_S) - _held(KEY_W)
	)
	return v.normalized() if v.length() > 1.0 else v

static func _held(key: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0
