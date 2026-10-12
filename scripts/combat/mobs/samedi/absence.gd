extends BaseMob

# L'Absence : boss de fin du samedi (ceux qui sont partis).
#   Phase 1 : presque invisible ; on ne la repere qu'a ses traces de pas et a ses attaques annoncees.
#   Phase 2 : elle prend la forme d'un etre aime ; des attaques douces mais incessantes.
#   Phase 3 : l'arene s'eteint, sauf un cercle de lumiere autour du joueur ; il faut la retrouver
#             dans le noir.

const STEP_EVERY := 0.4
const SOFT := Color(1, 0.88, 0.8, 0.9)
const PALE := Color(0.75, 0.8, 1.0)
const PHASE_THRESHOLDS := [0.66, 0.33]
const DARK := Color(0.07, 0.06, 0.1)

var phase := 1
var step_timer := STEP_EVERY
var stream_timer := 0.0
var ambient: CanvasModulate
var ambient_color := Color.WHITE
var player_light: PointLight2D

func _texture_path() -> String:
	return "res://assets/sprites/mobs/samedi/absence.png"

func _on_ready() -> void:
	display_name = "L'Absence"
	is_boss = true
	hp = 46
	chase_speed = 60.0
	attack_range = 2000.0
	telegraph_duration = 0.7
	attack_duration = 0.2
	cooldown_duration = 1.4
	auto_frames = false
	sprite.frame = 0
	sprite.self_modulate.a = 0.07

func take_hit(damage: int = 1) -> void:
	super(damage)
	if state == State.DEAD:
		return
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > PHASE_THRESHOLDS[0] else (2 if ratio > PHASE_THRESHOLDS[1] else 3)
	if new_phase > phase:
		phase = new_phase
		Sound.play("boss")
		if phase == 2:  # la forme d'un etre aime
			sprite.frame = 1
			sprite.self_modulate.a = 1.0
			cooldown_duration = 2.0
		else:
			_darken()

# Phase 3 : tout s'eteint, sauf un cercle de lumiere autour du joueur.
func _darken() -> void:
	for child in get_parent().get_children():
		if child is CanvasModulate:
			ambient = child
			ambient_color = child.color
			child.color = DARK
	var p := Hazards.player()
	if p:
		player_light = DreamTheme.make_light(Color(1, 0.95, 0.85), 150.0, 1.6)
		player_light.energy = 1.6  # independant du reglage par famille d'etage
		p.add_child(player_light)

func _on_death() -> void:
	if is_instance_valid(ambient):
		ambient.color = ambient_color
	if is_instance_valid(player_light):
		player_light.queue_free()

func _process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	if phase == 1:  # traces de pas qui s'effacent
		step_timer -= delta
		if step_timer <= 0.0 and velocity.length() > 5.0:
			step_timer = STEP_EVERY
			Hazards.zone(global_position + Vector2(0, 20), 7.0, "mark", 0.0, 1.2, PALE)
	elif phase == 2:  # des souvenirs doux, sans arret
		stream_timer -= delta
		if stream_timer <= 0.0 and player:
			stream_timer = 0.45
			Hazards.shoot(self, player.global_position - global_position, 95.0, SOFT)

func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.COOLDOWN and player:  # rode autour du joueur entre deux attaques
		velocity = (player.global_position - global_position).orthogonal().normalized() * chase_speed
		move_and_slide()
		global_position = Hazards.clamp_to_arena(global_position)

func _on_attack_begin() -> void:
	var target := player.global_position
	match phase:
		1:
			Hazards.zone(target, 60.0, "damage", 0.9, 0.2, PALE)
		2:
			Hazards.fan(self, target - global_position, 5, 60.0, 110.0, SOFT)
		3:
			Hazards.beam(global_position, target - global_position, 24.0, 0.9, 0.3, PALE)
