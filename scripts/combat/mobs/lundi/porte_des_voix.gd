extends BaseMob

# La Porte des Voix : boss de fin du lundi (l'enfant qui ecoute les disputes derriere la porte).
#   Phase 1 : la porte tremble, des mots-ombres la traversent en salves.
#   Phase 2 : elle s'entrouvre ; le noir aspire le joueur et repand un brouillard qui ralentit.
#             Elle n'est vulnerable que quand elle grince (fenetres courtes, annoncees).
#   Phase 3 : les voix se taisent une a une ; patterns plus lents mais plus larges.

const WORDS := ["CHUT", "PLUS TARD", "TAIS-TOI", "VA DORMIR", "PAS MAINTENANT"]
const WORD_COLOR := Color(0.95, 0.85, 1.0)
const PHASE_THRESHOLDS := [0.66, 0.33]  # ratio de PV ou l'on passe en phase 2, puis 3
const PULL_SPEED := 75.0
const FOG_COLOR := Color(0.45, 0.4, 0.6)
const CREAK_EVERY := 3.5
const CREAK_WARNING := 0.6
const CREAK_OPEN := 1.6

var phase := 1
var creak_timer := CREAK_EVERY
var open_timer := 0.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/lundi/porte_des_voix.png"

func _on_ready() -> void:
	display_name = "La Porte des Voix"
	is_boss = true
	hp = 40
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.1
	auto_frames = false
	sprite.frame = 0

func take_hit(damage: int = 1) -> void:
	super(damage)
	if state == State.DEAD:
		return
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > PHASE_THRESHOLDS[0] else (2 if ratio > PHASE_THRESHOLDS[1] else 3)
	if new_phase > phase:
		_enter_phase(new_phase)

func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	Sound.play("boss")
	Fx.flash(sprite, Color(1, 0.9, 0.7), 0.4)
	if phase == 2:  # la porte s'entrouvre : lumiere derriere, et le noir qui aspire
		sprite.frame = 1
		invulnerable = true
		creak_timer = CREAK_EVERY
	else:  # phase 3 : les voix s'eteignent, plus lentes mais plus larges
		invulnerable = false
		sprite.modulate = Color(0.75, 0.72, 0.85)
		base_color = sprite.modulate
		cooldown_duration *= 1.4

func _process(delta: float) -> void:
	super(delta)
	if phase != 2 or state == State.DEAD:
		return
	if open_timer > 0.0:
		open_timer -= delta
		if open_timer <= 0.0:
			invulnerable = true
		return
	creak_timer -= delta
	if creak_timer <= 0.0:
		creak_timer = CREAK_EVERY
		_creak()

# Grincement : la porte tremble (annonce), puis reste vulnerable un court instant.
func _creak() -> void:
	var shake := create_tween()
	for i in 4:
		shake.tween_property(sprite, "offset:x", 1.5 if i % 2 == 0 else -1.5, CREAK_WARNING / 4.0)
	shake.tween_property(sprite, "offset:x", 0.0, 0.05)
	await shake.finished
	if is_inside_tree() and state != State.DEAD and phase == 2:
		invulnerable = false
		open_timer = CREAK_OPEN
		Fx.flash(sprite, Color(1, 0.95, 0.6), 0.3)

func _physics_process(delta: float) -> void:
	super(delta)
	var p := Hazards.player()
	if phase == 2 and p and state != State.DEAD:
		p.add_external_velocity((global_position - p.global_position).normalized() * PULL_SPEED)

func _on_attack_begin() -> void:
	var direction := player.global_position - global_position
	match phase:
		1:
			Hazards.fan(self, direction, 5, 60.0, 160.0, WORD_COLOR, WORDS)
		2:
			Hazards.fan(self, direction, 3, 40.0, 150.0, WORD_COLOR, WORDS)
			for i in 2:
				var pos := Hazards.clamp_to_arena(player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(60, 150))
				Hazards.zone(pos, 70.0, "slow", 0.6, 4.0, FOG_COLOR)
		3:
			Hazards.radial(self, 14, 90.0, WORD_COLOR, randf() * TAU, WORDS)
			var gap := randf() * TAU
			Hazards.ring(global_position, 110.0, [[gap, 0.7], [gap + PI, 0.7]], WORD_COLOR)
