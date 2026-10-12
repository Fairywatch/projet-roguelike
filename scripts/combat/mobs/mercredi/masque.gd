extends BaseMob

# Masque (mercredi, Doute) : change de visage toutes les quelques secondes, et d'attaque avec :
#   joyeux : charge le joueur ; triste : larmes en eventail ; vide : presque invisible, s'approche.
# Variante : change deux fois plus vite. Cauchemar : charges et larmes renforcees.

const FACES := ["joyeux", "triste", "vide"]
const FACE_TIME := 2.6
const CHARGE_SPEED := 380.0
const TEAR := Color(0.55, 0.75, 1, 0.95)

var face := 0
var face_timer := FACE_TIME
var charge_dir := Vector2.ZERO

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mercredi/masque.png"

func _on_ready() -> void:
	display_name = "Masque"
	hp = 4
	chase_speed = 55.0
	attack_range = 220.0
	telegraph_duration = 0.6
	attack_duration = 0.4
	cooldown_duration = 1.0
	auto_frames = false
	_show_face()

func _show_face() -> void:
	sprite.frame = 1 if FACES[face] == "triste" else 0
	sprite.self_modulate.a = 0.15 if FACES[face] == "vide" else 1.0

func _process(delta: float) -> void:
	super(delta)
	face_timer -= delta * (2.0 if alt else 1.0)
	if face_timer <= 0.0 and state != State.DEAD:
		face_timer = FACE_TIME
		face = (face + 1) % FACES.size()
		_show_face()

func _on_telegraph_begin() -> void:
	charge_dir = (player.global_position - global_position).normalized()

func _on_attack_begin() -> void:
	match FACES[face]:
		"triste":
			Hazards.fan(self, player.global_position - global_position, 6 if nightmare else 4, 50.0, 140.0, TEAR)
		"vide":
			Hazards.zone(global_position, 46.0, "damage", 0.15, 0.2, Color(0.6, 0.6, 0.7))

func _physics_process(delta: float) -> void:
	if state == State.ATTACK and FACES[face] == "joyeux":
		velocity = charge_dir * CHARGE_SPEED * (1.2 if nightmare else 1.0)
		move_and_slide()
		var p := Hazards.player()
		if p and p.global_position.distance_to(global_position) < 30.0:
			p.take_damage()
		return
	super(delta)
