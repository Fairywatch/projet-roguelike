extends BaseMob

# Porte Close (jeudi, Frustration) : invulnerable de face, il faut la frapper de dos ou de cote.
# Elle se tourne lentement vers le joueur (un arc rouge montre son cote ferme) et claque devant
# elle. Variante : porte tournante, qui pivote sans arret. Cauchemar : se tourne plus vite.

const TURN_SPEED := 1.1   # radians/s
const SPIN_SPEED := 1.8
const FRONT_ARC := 0.45   # cos de l'angle : en dessous, le coup passe (dos ou cote)
const SLAM := Color(1, 0.55, 0.3)

var facing := Vector2.LEFT

func _texture_path() -> String:
	return "res://assets/sprites/mobs/jeudi/porte_close.png"

func _on_ready() -> void:
	display_name = "Porte Close"
	hp = 4
	chase_speed = 45.0
	attack_range = 110.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.2

func _process(delta: float) -> void:
	super(delta)
	if state == State.DEAD or player == null:
		return
	if alt:
		facing = facing.rotated(SPIN_SPEED * delta)
	else:
		var wanted := (player.global_position - global_position).angle()
		facing = Vector2.from_angle(rotate_toward(facing.angle(), wanted, TURN_SPEED * delta * (1.4 if nightmare else 1.0)))
	sprite.flip_h = facing.x > 0.0

func _draw() -> void:
	super()
	draw_arc(Vector2.ZERO, 34.0, facing.angle() - 1.0, facing.angle() + 1.0, 16, Color(1, 0.3, 0.3, 0.7), 3.0)

func take_hit(damage: int = 1) -> void:
	var p := Hazards.player()
	if p and facing.dot((p.global_position - global_position).normalized()) > FRONT_ARC:
		Fx.flash(sprite, Color(0.7, 0.7, 0.8), 0.08)  # le coup rebondit sur la porte
		return
	super(damage)

func _on_telegraph_begin() -> void:
	Hazards.zone(global_position + facing * 55.0, 52.0, "damage", telegraph_duration, 0.2, SLAM)
