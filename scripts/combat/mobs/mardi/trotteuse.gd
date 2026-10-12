extends BaseMob

# Trotteuse (mardi, Stress) : vise (trait annonce), puis fonce en ligne droite, un peu plus vite
# a chaque charge. Variante : une deuxieme aiguille charge en meme temps, les trajectoires se
# croisent. Cauchemar : accelere plus vite.

const BASE_DASH := 320.0
const DASH_GAIN := 45.0
const DASH_MAX := 560.0
const HIT_RANGE := 30.0

var dash_speed := BASE_DASH
var dash_dir := Vector2.ZERO
var partner := false

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mardi/trotteuse.png"

func _on_ready() -> void:
	display_name = "Trotteuse"
	hp = 3
	chase_speed = 70.0
	attack_range = 240.0
	telegraph_duration = 0.55
	attack_duration = 0.45
	cooldown_duration = 0.9
	if alt and not partner:
		var side := (player.global_position - global_position).orthogonal().normalized() * 200.0
		spawn_ally("mardi/trotteuse", player.global_position + side, {"partner": true, "nightmare": nightmare})

func _on_telegraph_begin() -> void:
	dash_dir = (player.global_position - global_position).normalized()
	sprite.flip_h = dash_dir.x < 0
	Hazards.beam(global_position, dash_dir, 6.0, telegraph_duration, 0.0, Color(1, 0.85, 0.4))

func _physics_process(delta: float) -> void:
	if state != State.ATTACK:
		super(delta)
		return
	velocity = dash_dir * dash_speed
	move_and_slide()
	var p := Hazards.player()
	if p and p.global_position.distance_to(global_position) < HIT_RANGE:
		p.take_damage()

func _on_attack_end() -> void:
	dash_speed = minf(DASH_MAX, dash_speed + DASH_GAIN * (1.5 if nightmare else 1.0))
