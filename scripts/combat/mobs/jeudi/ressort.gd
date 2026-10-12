extends BaseMob

# Ressort (jeudi, Frustration) : rebondit en ligne droite sur les murs de l'arene, un peu plus
# vite a chaque rebond ; le toucher blesse. Variante : se divise a chaque rebond (3 fois au plus).
# Cauchemar : accelere plus fort.

const START_SPEED := 170.0
const SPEED_GAIN := 25.0
const MAX_SPEED := 420.0
const HIT_RANGE := 26.0
const MAX_SPLITS := 3

var move_dir := Vector2.from_angle(randf() * TAU)
var speed := START_SPEED
var splits := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/jeudi/ressort.png"

func _on_ready() -> void:
	display_name = "Ressort"
	hp = 3

func _physics_process(delta: float) -> void:
	if state != State.CHASE:  # mort ou etourdi
		return
	var next := global_position + move_dir * speed * delta
	var bounced := false
	if next.x < Hazards.ARENA.position.x or next.x > Hazards.ARENA.end.x:
		move_dir.x = -move_dir.x
		bounced = true
	if next.y < Hazards.ARENA.position.y or next.y > Hazards.ARENA.end.y:
		move_dir.y = -move_dir.y
		bounced = true
	if bounced:
		speed = minf(MAX_SPEED, speed + SPEED_GAIN * (1.6 if nightmare else 1.0))
		var squish := create_tween()
		squish.tween_property(sprite, "scale:y", sprite.scale.y * 0.6, 0.05)
		squish.tween_property(sprite, "scale:y", sprite.scale.y, 0.1)
		if alt and splits < MAX_SPLITS:
			splits += 1
			spawn_ally("jeudi/ressort", global_position, {"splits": MAX_SPLITS, "move_dir": move_dir.rotated(0.8), "speed": speed})
	global_position = Hazards.clamp_to_arena(global_position + move_dir * speed * delta)
	var p := Hazards.player()
	if p and p.global_position.distance_to(global_position) < HIT_RANGE:
		p.take_damage()
