extends BaseMob

# Lettre sans reponse (samedi, Solitude) : une enveloppe qui vole de facon hesitante et lance des
# avions de papier qui suivent lentement le joueur. Variante : se plie en 3 avions quand on la
# frappe. Cauchemar : avions qui suivent mieux.

const PLANE := Color(0.95, 0.95, 0.9)
const PLANE_SPEED := 120.0

var drift := randf() * TAU

func _texture_path() -> String:
	return "res://assets/sprites/mobs/samedi/lettre.png"

func _on_ready() -> void:
	display_name = "Lettre sans réponse"
	hp = 3
	chase_speed = 50.0
	attack_range = 300.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 2.0

func _chase_velocity(to_player: Vector2) -> Vector2:
	drift += 0.08
	return (to_player.normalized() + Vector2.from_angle(drift) * 0.9).normalized() * chase_speed

func _plane(direction: Vector2) -> void:
	var plane := Hazards.shoot(self, direction, PLANE_SPEED, PLANE, "", 4.5)
	plane.homing = 1.8 if nightmare else 1.2

func _on_attack_begin() -> void:
	var aim := player.global_position - global_position
	_plane(aim.rotated(0.4))
	_plane(aim.rotated(-0.4))

func take_hit(damage: int = 1) -> void:
	if alt and state != State.DEAD:
		for i in 3:
			_plane(Vector2.from_angle(TAU * i / 3.0))
		_die()
		return
	super(damage)
