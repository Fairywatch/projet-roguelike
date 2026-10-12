extends BaseMob

# Pile ou Face (mercredi, Doute) : une piece qui tourne sur elle-meme (invulnerable), puis
# retombe : sur PILE elle reste invulnerable, sur FACE elle est vulnerable et lance des pieces.
# On ne sait qu'au dernier moment. Variante : lance des pieces qui roulent en courbes.
# Cauchemar : plus de pieces.

const COIN_COLOR := Color(1, 0.85, 0.35)

var face_up := false

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mercredi/pile_ou_face.png"

func _on_ready() -> void:
	display_name = "Pile ou Face"
	hp = 4
	chase_speed = 40.0
	attack_range = 2000.0
	telegraph_duration = 0.9  # la piece tourne
	attack_duration = 0.2
	cooldown_duration = 2.4   # posee : pile ou face
	auto_frames = false
	invulnerable = true

func _process(delta: float) -> void:
	super(delta)
	if state == State.TELEGRAPH:  # rotation : la piece s'aplatit et alterne ses faces
		sprite.scale.x = sprite.scale.y * absf(cos(bob_time * 14.0))
		sprite.frame = int(bob_time * 9.0) % 2
	else:
		sprite.scale.x = sprite.scale.y

func _on_telegraph_begin() -> void:
	invulnerable = true

func _on_attack_begin() -> void:
	face_up = randf() < 0.5
	sprite.frame = 1 if face_up else 0
	invulnerable = not face_up
	if not face_up:
		return
	var count := 6 if nightmare else 4
	if alt:
		for i in count:
			var coin := Hazards.shoot(self, Vector2.from_angle(TAU * i / count), 120.0, COIN_COLOR)
			coin.curve = 1.6 if i % 2 == 0 else -1.6
	else:
		Hazards.radial(self, count, 150.0, COIN_COLOR, randf() * TAU)
