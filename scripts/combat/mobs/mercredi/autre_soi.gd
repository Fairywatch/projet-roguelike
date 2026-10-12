extends BaseMob

# L'Autre Soi : boss de fin du mercredi (qui devenir ?). Un double sombre du reveur.
#   Phase 1 : il utilise les memes coups que le joueur : dash, coup d'arc, "objet actif" (anneau).
#   Phase 2 : il se divise en trois futurs ; deux copies chargent une fois puis disparaissent.
#   Phase 3 : il cesse d'attaquer quand le joueur cesse d'attaquer (facon Undertale). Si le joueur
#             reste en paix assez longtemps, le doute s'apaise et le double s'efface : victoire.

const DASH_SPEED := 520.0
const SLASH_COLOR := Color(0.6, 0.35, 0.8)
const PHASE_THRESHOLDS := [0.66, 0.33]
const CALM_AFTER := 2.0   # secondes sans attaquer avant que le double se calme
const PEACE_TIME := 7.0   # secondes de paix pour qu'il s'efface

var phase := 1
var cycle := 0
var dash_dir := Vector2.ZERO
var future := false  # copie de la phase 2 : charge une fois puis disparait
var peace := 0.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mercredi/autre_soi.png"

func _on_ready() -> void:
	display_name = "L'Autre Soi" if not future else "Futur possible"
	is_boss = not future
	hp = 1 if future else 46
	chase_speed = 90.0
	attack_range = 2000.0 if not future else 600.0
	telegraph_duration = 0.5
	attack_duration = 0.35
	cooldown_duration = 0.9
	set_display_scale(2.0 if future else 2.6)
	if future:
		sprite.self_modulate.a = 0.6

func _player_calm() -> bool:
	var p := Hazards.player()
	return p != null and Time.get_ticks_msec() / 1000.0 - p.last_attack_time > CALM_AFTER

func take_hit(damage: int = 1) -> void:
	super(damage)
	if state == State.DEAD or future:
		return
	peace = 0.0
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > PHASE_THRESHOLDS[0] else (2 if ratio > PHASE_THRESHOLDS[1] else 3)
	if new_phase > phase:
		phase = new_phase
		Sound.play("boss")
		Fx.flash(sprite, Color(0.9, 0.8, 1), 0.4)

func _process(delta: float) -> void:
	super(delta)
	if phase != 3 or state == State.DEAD:
		return
	# Phase 3 : en paix, il se calme (teinte bleue) ; assez de paix et il s'efface.
	if _player_calm():
		peace += delta
		sprite.modulate = Color(0.6, 0.7, 1.0)
		sprite.self_modulate.a = clampf(1.0 - peace / PEACE_TIME, 0.15, 1.0)
		if peace >= PEACE_TIME:
			_die()
	else:
		peace = 0.0
		sprite.self_modulate.a = 1.0

func _start_telegraph() -> void:
	if phase == 3 and _player_calm():
		return  # il ne frappe pas qui ne frappe pas
	super()

func _on_telegraph_begin() -> void:
	dash_dir = (player.global_position - global_position).normalized()
	sprite.flip_h = dash_dir.x < 0
	Hazards.beam(global_position, dash_dir, 8.0, telegraph_duration, 0.0, SLASH_COLOR)

func _on_attack_begin() -> void:
	cycle += 1
	if future:
		return
	if phase == 2 and cycle % 3 == 0:
		for side in [-1, 1]:
			var copy := spawn_ally("mercredi/autre_soi", position + dash_dir.orthogonal() * side * 90.0, {"future": true})
			get_tree().create_timer(2.2).timeout.connect(func(): if is_instance_valid(copy) and copy.is_inside_tree(): copy._die())
	if cycle % 4 == 0:
		var gap := randf() * TAU
		Hazards.ring(global_position, 170.0, [[gap, 0.6], [gap + PI, 0.6]], SLASH_COLOR)

func _physics_process(delta: float) -> void:
	if state != State.ATTACK:
		super(delta)
		return
	velocity = dash_dir * DASH_SPEED
	move_and_slide()

func _on_attack_end() -> void:
	# Fin du dash : coup d'arc devant lui, comme le joueur.
	Hazards.zone(global_position + dash_dir * 40.0, 46.0, "damage", 0.2, 0.15, SLASH_COLOR)
