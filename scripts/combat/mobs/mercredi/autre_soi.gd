extends BaseMob

# L'Autre Soi : boss de fin du mercredi (qui devenir ?). Le double du reveur, son miroir exact :
# il copie au debut du combat les statistiques et les objets du joueur (PlayerStats), et s'en sert
# contre lui. Un build "intouchable" se retourne donc contre celui qui l'a construit.
#   Copie : vitesse, cadence, portee et degats du coup, longueur du dash, PV max (plus de coeurs,
#   plus de PV pour lui), critiques, esquive, coups bloques, survies, soin en frappant, epines,
#   ralentissement au coup, traine du dash, et l'objet actif (meme effet, retourne).
#   Phase 1 : il se bat comme le joueur : il approche, dashe, frappe en arc devant lui.
#   Phase 2 : il se divise en trois futurs ; deux copies chargent une fois puis disparaissent.
#   Phase 3 : il cesse d'attaquer quand le joueur cesse d'attaquer (facon Undertale). Si le joueur
#             reste en paix assez longtemps, le doute s'apaise et le double s'efface : victoire.

const SLASH_COLOR := Color(0.6, 0.35, 0.8)
const PHASE_THRESHOLDS := [0.66, 0.33]
const CALM_AFTER := 2.0   # secondes sans attaquer avant que le double se calme
const PEACE_TIME := 7.0   # secondes de paix pour qu'il s'efface
const BASE_HP := 46
const CHASE_RATIO := 0.55   # il marche a 55 % de la vitesse du joueur (le dash comble l'ecart)
const DASH_RATIO := 0.85
const DASH_LENGTH := 1.9    # son dash dure 1,9 fois celui du joueur (il doit traverser l arene)
const COOLDOWN_RATIO := 2.3 # une frappe pour 2,3 du joueur : il copie le rythme, pas la frenesie
const SLASH_RADIUS := 46.0  # a portee de base du joueur (30)
const THORNS_DELAY := 1.5   # ses epines ne piquent qu'une fois par 1,5 s
const ACTIVE_EVERY := 4     # il sort son objet actif une attaque sur quatre
const REVIVE_RATIO := 0.3

var phase := 1
var cycle := 0
var dash_dir := Vector2.ZERO
var future := false  # copie de la phase 2 : charge une fois puis disparait
var peace := 0.0

# Ce qu'il a copie du joueur.
var dash_speed := PlayerStats.DASH_SPEED * DASH_RATIO
var slash_radius := SLASH_RADIUS
var slash_damage := 1
var crit := 0.0
var evasion := 0.0
var shield := 0
var lives := 0
var heal_on_hit := 0.0
var thorns := 0
var slow_on_hit := false
var dash_trail := false
var active := ""
var thorns_timer := 0.0
var boost_timer := 0.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mercredi/autre_soi.png"

func _on_ready() -> void:
	display_name = "L'Autre Soi" if not future else "Futur possible"
	is_boss = not future
	telegraph_duration = 0.5
	set_display_scale(2.0 if future else 2.6)
	_copy_player()
	if future:
		hp = 1
		attack_range = 600.0
		sprite.self_modulate.a = 0.6

# Le miroir : tout ce que le joueur a, il l'a aussi.
func _copy_player() -> void:
	hp = ceili(BASE_HP * (0.7 + 0.1 * GameState.max_hp()))  # 3 PV : 46 ; 8 PV : 69
	chase_speed = PlayerStats.move_speed() * CHASE_RATIO
	attack_range = 2000.0
	attack_duration = PlayerStats.dash_duration() * DASH_LENGTH
	cooldown_duration = maxf(0.45, PlayerStats.attack_cooldown() * COOLDOWN_RATIO)
	dash_speed = PlayerStats.DASH_SPEED * DASH_RATIO
	slash_radius = SLASH_RADIUS * PlayerStats.reach() / PlayerStats.ATTACK_REACH
	slash_damage = mini(2, PlayerStats.damage())
	crit = PlayerStats.crit()
	evasion = PlayerStats.evasion()
	shield = PlayerStats.shield()
	lives = PlayerStats.extra_lives()
	heal_on_hit = PlayerStats.heal_on_hit()
	thorns = PlayerStats.thorns()
	slow_on_hit = GameState.mod("slow_on_hit") > 0.0
	dash_trail = GameState.mod("dash_trail") > 0.0
	active = GameState.active_item_id

func _player_calm() -> bool:
	var p := Hazards.player()
	return p != null and Time.get_ticks_msec() / 1000.0 - p.last_attack_time > CALM_AFTER

func take_hit(damage: int = 1) -> void:
	if state == State.DEAD:
		return
	if future:
		super(damage)
		return
	# Ses objets defensifs, copies du joueur : esquive, puis coups bloques.
	if randf() < evasion:
		Fx.flash(sprite, Color(0.6, 0.9, 1), 0.15)
		return
	if shield > 0:
		shield -= 1
		Fx.flash(sprite, Color(1, 0.9, 0.5), 0.2)
		return
	_prick()
	if hp - damage <= 0 and lives > 0:  # comme le Croque-mort : il survit au coup fatal
		lives -= 1
		hp = maxi(1, ceili(max_hp * REVIVE_RATIO))
		hp_changed.emit(hp)
		Fx.flash(sprite, Color(1, 1, 1), 0.4)
		Sound.play("boss")
		return
	super(damage)
	if state == State.DEAD:
		return
	peace = 0.0
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > PHASE_THRESHOLDS[0] else (2 if ratio > PHASE_THRESHOLDS[1] else 3)
	if new_phase > phase:
		phase = new_phase
		Sound.play("boss")
		Fx.flash(sprite, Color(0.9, 0.8, 1), 0.4)

# Ses epines : frapper le double de pres pique en retour (une fois par THORNS_DELAY).
func _prick() -> void:
	var p := Hazards.player()
	if thorns > 0 and thorns_timer <= 0.0 and p and p.global_position.distance_to(global_position) < 90.0 + slash_radius:
		thorns_timer = THORNS_DELAY
		p.take_damage()

func _process(delta: float) -> void:
	super(delta)
	thorns_timer = maxf(0.0, thorns_timer - delta)
	boost_timer = maxf(0.0, boost_timer - delta)
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
			get_tree().create_timer(2.2, false).timeout.connect(func(): if is_instance_valid(copy) and copy.is_inside_tree(): copy._die())
	if cycle % ACTIVE_EVERY == 0:
		_use_active()

# Son objet actif : celui du joueur, retourne contre lui (un anneau s'il n'en a pas).
func _use_active() -> void:
	var p := Hazards.player()
	match active:
		"sept_ans_de_malheur":  # invincible un instant
			invulnerable = true
			Fx.flash(sprite, Color(0.8, 0.9, 1.0), 0.4)
			if await pause(1.5):
				invulnerable = false
		"mouchoir_usage":
			hp = mini(max_hp, hp + ceili(max_hp * 0.1))
			hp_changed.emit(hp)
			Fx.flash(sprite, Color(0.5, 1.0, 0.6), 0.3)
		"reveil_strident":  # sonne le joueur : il ralentit fort
			Hazards.ring(global_position, 260.0, [], Color(1, 0.95, 0.5))
			if p and p.global_position.distance_to(global_position) < 220.0:
				p.apply_slow(1.2, 0.35)
		"oreiller_volant":
			Hazards.zone(global_position, 150.0, "damage", 0.6, 0.15, Color(1, 1, 1))
		"tasse_de_cafe":
			boost_timer = 4.0
			Fx.flash(sprite, Color(0.9, 0.7, 0.4), 0.3)
		_:
			var gap := randf() * TAU
			Hazards.ring(global_position, 170.0, [[gap, 0.6], [gap + PI, 0.6]], SLASH_COLOR)

func _physics_process(delta: float) -> void:
	if state != State.ATTACK:
		var base := chase_speed
		if boost_timer > 0.0:
			chase_speed = base * 1.5
		super(delta)
		chase_speed = base
		return
	velocity = dash_dir * dash_speed * (1.5 if boost_timer > 0.0 else 1.0)
	move_and_slide()
	if dash_trail and not future and Engine.get_physics_frames() % 6 == 0:
		Hazards.zone(global_position, 22.0, "damage", 0.35, 0.5, SLASH_COLOR)

func _on_attack_end() -> void:
	# Fin du dash : coup d'arc devant lui, comme le joueur, avec sa portee et ses degats.
	var at := global_position + dash_dir * (slash_radius - 6.0)
	var zone = Hazards.zone(at, slash_radius, "damage", 0.2, 0.15, SLASH_COLOR)  # zone.gd : degats reglables
	zone.damage = slash_damage + (1 if randf() < crit else 0)
	if future:
		return
	var p := Hazards.player()
	if p and p.global_position.distance_to(at) <= slash_radius + 8.0:
		if slow_on_hit:
			p.apply_slow(1.0, 0.5)
		if randf() < heal_on_hit:
			hp = mini(max_hp, hp + 1)
			hp_changed.emit(hp)
