extends BaseMob

# La Colere : boss de fin du jeudi (l'effort jamais recompense). Un nuage d'orage.
#   Phase 1 : le grondement ; des eclairs annonces tombent en ligne vers le joueur.
#   Phase 2 : la rage ; il accelere et les bords de l'arene se couvrent de zones brulantes.
#   Phase 3 : l'orage passe ; il alterne accalmies (bleu, on peut le frapper) et bourrasques
#             (rouge) : le frapper pendant une bourrasque le SOIGNE. Il faut frapper au bon moment,
#             sans s'acharner.

const LIGHTNING := Color(1, 0.95, 0.5)
const FIRE := Color(1, 0.4, 0.2)
const PHASE_THRESHOLDS := [0.66, 0.33]
const CALM_TIME := 2.2
const GUST_TIME := 2.0
const GUST_HEAL := 2
const COOLDOWNS := [1.2, 0.72, 1.5]  # par phase : normal, rage (plus vite), orage qui passe (plus lent)

var phase := 1
var cycle := 0
var gust := false
var mood_timer := CALM_TIME

func _texture_path() -> String:
	return "res://assets/sprites/mobs/jeudi/colere.png"

func _on_ready() -> void:
	display_name = "La Colere"
	is_boss = true
	hp = 48
	chase_speed = 40.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 1.2
	set_display_scale(2.4)

func take_hit(damage: int = 1) -> void:
	if phase == 3 and gust and state != State.DEAD:
		hp = mini(max_hp, hp + GUST_HEAL)  # s'acharner pendant la bourrasque l'attise
		Fx.flash(sprite, Color(1, 0.3, 0.2), 0.15)
		return
	super(damage)
	if state == State.DEAD:
		return
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > PHASE_THRESHOLDS[0] else (2 if ratio > PHASE_THRESHOLDS[1] else 3)
	if new_phase > phase:
		phase = new_phase
		Sound.play("boss")
		Fx.flash(sprite, Color(1, 0.9, 0.6), 0.4)
		cooldown_duration = COOLDOWNS[phase - 1]

func _process(delta: float) -> void:
	super(delta)
	if phase != 3 or state == State.DEAD:
		return
	mood_timer -= delta
	if mood_timer <= 0.0:
		gust = not gust
		mood_timer = GUST_TIME if gust else CALM_TIME
	sprite.self_modulate = Color(1, 0.55, 0.5) if gust else Color(0.6, 0.75, 1.0)

func _on_attack_begin() -> void:
	cycle += 1
	var target := player.global_position
	var from := global_position
	match phase:
		1, 2:
			for i in 6:  # eclairs en ligne, du nuage vers le joueur
				var spot := from.lerp(target, (i + 1) / 6.0) + Vector2(randf_range(-20, 20), randf_range(-20, 20))
				Hazards.zone(Hazards.clamp_to_arena(spot), 34.0, "damage", 0.6 + i * 0.08, 0.15, LIGHTNING)
			if phase == 2 and cycle % 3 == 0:
				_burn_edges()
		3:
			if gust:
				Hazards.radial(self, 12, 120.0, LIGHTNING, randf() * TAU)
			else:
				Hazards.zone(target, 80.0, "damage", 1.0, 0.2, LIGHTNING)

func _burn_edges() -> void:
	for x in range(80, 840, 95):
		Hazards.zone(Vector2(x, 70), 40.0, "damage", 0.9, 3.0, FIRE)
		Hazards.zone(Vector2(x, 470), 40.0, "damage", 0.9, 3.0, FIRE)
	for y in range(160, 400, 95):
		Hazards.zone(Vector2(70, y), 40.0, "damage", 0.9, 3.0, FIRE)
		Hazards.zone(Vector2(830, y), 40.0, "damage", 0.9, 3.0, FIRE)
