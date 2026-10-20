extends BaseMob

# Veilleuse fatiguee (lundi, Fatigue) : garde ses distances et lance des orbes lents ; de temps
# en temps elle s'eteint et se rallume ailleurs, pres du joueur.
# Variante : orbes en spirale. Cauchemar : un orbe de plus.

const ORB_SPEED := 115.0
const ORB_COLOR := Color(1, 0.88, 0.55, 0.95)
const TELEPORT_DISTANCE := Vector2(130, 190)

var flicker_timer := randf_range(2.5, 4.0)
var spin := 0.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/lundi/veilleuse.png"

func _on_ready() -> void:
	display_name = "Veilleuse fatiguée"
	hp = 3
	chase_speed = 40.0
	attack_range = 260.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.4
	add_child(DreamTheme.make_light(Color(1, 0.85, 0.5), 50.0, 0.8))

func _process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	flicker_timer -= delta
	if flicker_timer <= 0.0:
		flicker_timer = randf_range(3.0, 4.5)
		var tween := create_tween()
		tween.tween_property(sprite, "self_modulate:a", 0.1, 0.25)
		tween.tween_callback(_teleport)
		tween.tween_property(sprite, "self_modulate:a", 1.0, 0.25)

func _teleport() -> void:
	var p := Hazards.player()
	if p and state != State.DEAD:
		var distance := randf_range(TELEPORT_DISTANCE.x, TELEPORT_DISTANCE.y)
		global_position = Hazards.clamp_to_arena(p.global_position + Vector2.from_angle(randf() * TAU) * distance)

func _on_attack_begin() -> void:
	var direction := player.global_position - global_position
	if alt:
		spin += 0.35
		Hazards.radial(self, 10 if nightmare else 8, ORB_SPEED, ORB_COLOR, spin)
	else:
		Hazards.fan(self, direction, 4 if nightmare else 3, 26.0, ORB_SPEED, ORB_COLOR)
