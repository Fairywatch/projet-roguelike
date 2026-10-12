extends BaseMob

# Paupiere lourde (lundi, Fatigue) : fermee, elle est invulnerable. Elle s'ouvre pour viser
# (rayon annonce par un trait qui clignote), tire, puis reste ouverte un instant avant de se
# refermer : c'est la fenetre pour la frapper.
# Variante : deux paupieres qui s'ouvrent a tour de role. Cauchemar : rayon plus large.

const OPEN_AFTER_SHOT := 0.8

var twin := false

func _texture_path() -> String:
	return "res://assets/sprites/mobs/lundi/paupiere.png"

func _on_ready() -> void:
	display_name = "Paupiere lourde"
	hp = 3
	chase_speed = 30.0
	attack_range = 340.0
	telegraph_duration = 0.8
	attack_duration = 0.35
	cooldown_duration = 1.6
	auto_frames = false
	_close()
	if alt and not twin:
		_spawn_twin.call_deferred()
	if twin:  # decalee d'un demi-cycle : les deux paupieres alternent
		state = State.COOLDOWN
		_start_cooldown()

func _spawn_twin() -> void:
	var other: BaseMob = get_script().new()
	other.twin = true
	other.nightmare = nightmare
	other.position = Hazards.clamp_to_arena(position + Vector2(-160, 0))
	get_parent().add_child(other)

func _close() -> void:
	sprite.frame = 0
	invulnerable = true

func _on_telegraph_begin() -> void:
	sprite.frame = 1
	invulnerable = false
	var direction := (player.global_position - global_position).normalized()
	Hazards.beam(global_position, direction, 36.0 if nightmare else 26.0, telegraph_duration, attack_duration)

func _on_attack_end() -> void:
	await get_tree().create_timer(OPEN_AFTER_SHOT).timeout
	if state != State.DEAD and state != State.TELEGRAPH:
		_close()
