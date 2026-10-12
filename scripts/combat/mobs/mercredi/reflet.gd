extends BaseMob

# Reflet (mercredi, Doute) : une copie de verre du reveur qui se place en miroir du joueur ; des
# qu'elle est alignee avec lui (meme ligne ou meme colonne), elle tire un rayon (annonce).
# Variante : deux reflets, l'un en miroir horizontal, l'autre vertical. Cauchemar : rayon large.
# mirror : "point" (symetrie centrale), "horizontal" ou "vertical".

const MOVE_SPEED := 210.0
const ALIGN := 26.0

var mirror := "point"

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mercredi/reflet.png"

func _on_ready() -> void:
	display_name = "Reflet"
	hp = 3
	telegraph_duration = 0.6
	attack_duration = 0.3
	cooldown_duration = 1.2
	if alt and mirror == "point":
		mirror = "horizontal"
		spawn_ally("mercredi/reflet", position + Vector2(0, 80), {"mirror": "vertical", "nightmare": nightmare})

func _mirror_target() -> Vector2:
	var center := Hazards.ARENA.get_center()
	var p := player.global_position
	match mirror:
		"horizontal":
			return Vector2(2.0 * center.x - p.x, p.y + 60.0)
		"vertical":
			return Vector2(p.x + 60.0, 2.0 * center.y - p.y)
	return 2.0 * center - p

func _physics_process(_delta: float) -> void:
	if state != State.CHASE or player == null:
		return
	velocity = (Hazards.clamp_to_arena(_mirror_target()) - global_position).limit_length(MOVE_SPEED)
	move_and_slide()
	var offset := player.global_position - global_position
	if absf(offset.x) < ALIGN or absf(offset.y) < ALIGN:
		velocity = Vector2.ZERO
		_start_telegraph()

func _on_telegraph_begin() -> void:
	var direction := (player.global_position - global_position).normalized()
	Hazards.beam(global_position, direction, 30.0 if nightmare else 20.0, telegraph_duration, attack_duration, Color(0.7, 0.85, 1))
