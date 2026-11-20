extends CharacterBody2D

signal hp_changed(hp: int)
signal died
signal item_message(text: String)
# Chaque attaque du joueur, avec la position de son coup (l'Echo la repete, l'Autre Soi l'observe).
signal attacked(at: Vector2)
signal special_used

# Valeurs de base et plafonds des statistiques : voir PlayerStats.
const SPEED := PlayerStats.SPEED
const DASH_SPEED := PlayerStats.DASH_SPEED
# Prise de vitesse et freinage tres courts (~0,08 s et ~0,1 s) : du liant sans perdre en reactivite.
const ACCELERATION := 2600.0
const FRICTION := 2000.0
const DASH_DURATION := PlayerStats.DASH_DURATION
const DASH_COOLDOWN_BASE := PlayerStats.DASH_COOLDOWN
const ATTACK_DURATION := 0.15
const ATTACK_COOLDOWN := PlayerStats.ATTACK_COOLDOWN
const ATTACK_REACH := PlayerStats.ATTACK_REACH
const HURT_INVINCIBILITY := PlayerStats.HURT_INVINCIBILITY
# Enchainement : trois coups rapproches, le troisieme frappe plus fort et plus loin, puis on souffle.
const COMBO_WINDOW := 0.75      # secondes pour placer le coup suivant
const COMBO_FINISHER := 3
const FINISHER_REACH := 12.0
const FINISHER_RECOVERY := 1.7  # le coup final rallonge le temps avant la prochaine attaque
# Coup plongeant : attaquer pendant un dash ou juste apres frappe plus fort, d'un peu plus loin.
const DASH_STRIKE_WINDOW := 0.25
const DASH_STRIKE_COOLDOWN := 2.5  # sinon, avec un dash toutes les 0,6 s, il doublait presque les degats
const DASH_STRIKE_REACH := 8.0
const REVEIL_RADIUS := 220.0
const OREILLER_RADIUS := 150.0
const OREILLER_DAMAGE := 2
const THORNS_RADIUS := 90.0
const CAFE_DURATION := 4.0
const CAFE_SPEED_MULT := 1.5
# Styles d'attaque (PlayerStats.STYLES) : formes du coup.
const THRUST_WIDTH := 16.0      # estoc : largeur de la lance
const SPIN_EXTRA := 12.0        # toupie : rayon = portee + SPIN_EXTRA, tout autour
const MALLET_SCALE := 1.7       # maillet : zone du coup agrandie
const MALLET_STUN := 0.45       # maillet : assomme les ennemis ordinaires (pas les boss)
const MALLET_PUSH := 30.0
const PELLET_RANGE := 300.0     # fronde : portee de la bille (+3 px par point de portee en plus)
const PELLET_SPREAD := 0.26     # fronde : ecart des trois billes du 3e coup
# Pantoufles-fusees : le dash blesse ; un ennemi touche ramene la recharge a cette part au plus.
const DASH_HIT_RADIUS := 44.0  # demi-taille du joueur + celle d'un ennemi moyen : il bute contre eux
const DASH_HIT_REFUND := 0.35
# Appuis memorises : une attaque (ou un dash) demandee juste avant la fin de la recharge part des
# qu'elle est prete, au lieu d'etre perdue. Les enchainements deviennent fluides.
const ATTACK_BUFFER := 0.18
const DASH_BUFFER := 0.12
# Secousse d'ecran : "trauma" de 0 a 1, qui decroit en temps reel ; l'ecran bouge de trauma^2
# (les petits coups bougent a peine, les gros secouent), en sinus lisses plutot qu'au hasard.
const SHAKE_DECAY := 1.6
const SHAKE_OFFSET := Vector2(9, 6)
const DASH_GHOST_EVERY := 0.03
const SPRITE_SCALE := Vector2(2, 2)  # taille du sprite dans la scene : reference des etirements

const DashTrailScene := preload("res://scenes/combat/DashTrail.tscn")
const MirrorDecoyScene := preload("res://scenes/combat/MirrorDecoy.tscn")

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var facing := Vector2.DOWN
var invincible := false
var dashing := false
var dead := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var attack_cooldown_timer := 0.0
var dash_trail_timer := 0.0
var hurt_timer := 0.0
var slash_timer := 0.0
var trauma := 0.0
var shake_time := 0.0
var kick := Vector2.ZERO  # petit a-coup de camera dans le sens du coup
var attack_buffer := 0.0
var dash_buffer := 0.0
var dash_ghost_timer := 0.0
var swing_side := 1.0  # sens du balayage, alterne a chaque coup de l'enchainement
var squash_tween: Tween
var special_timer := 0.0  # recharge de la rafale de plumes
var special_buffer := 0.0
var special_cooldown_effective := PlayerStats.SPECIAL_COOLDOWN
var bob_time := 0.0
var ring_timer := 0.0
var ring_color := Color(1, 0.95, 0.5)
var ring_radius := REVEIL_RADIUS
var speed_boost_timer := 0.0
# Effets des ennemis : attraction (baillements...) remise a zero chaque frame, et ralentissement.
var external_velocity := Vector2.ZERO
var slow_timer := 0.0
var slow_factor := 1.0
var move_velocity := Vector2.ZERO  # deplacement voulu, lisse (hors dash et forces externes)
var last_attack_time := -100.0  # secondes (Time), pour les ennemis qui reagissent a nos attaques
var combo := 0            # coups deja places dans l'enchainement en cours
var combo_timer := 0.0    # temps restant pour le coup suivant
var since_dash := 10.0    # secondes depuis la fin du dernier dash
var dash_strike_timer := 0.0  # temps avant le prochain coup plongeant
var strike_damage := 1    # degats du coup en cours
var strike_reach := ATTACK_REACH
var strike_kind := ""     # "" (coup simple), "finisher" (3e coup) ou "dash" (coup plongeant)

# Statistiques calculees a partir des passifs (apply_items).
var max_hp := GameState.BASE_MAX_HP
var hp := GameState.BASE_MAX_HP
var attack_damage := 1
var move_speed := SPEED
var dash_cooldown_effective := DASH_COOLDOWN_BASE
var attack_cooldown_effective := ATTACK_COOLDOWN
var dash_duration := DASH_DURATION
var reach := ATTACK_REACH
var hurt_invincibility := HURT_INVINCIBILITY
var has_dash_trail := false
var has_slow_on_hit := false
var heal_on_hit_chance := 0.0
var heal_on_kill_chance := 0.0
var crit_chance := 0.0
var evasion := 0.0
var knockback := 0.0
var thorns := 0
var extra_lives := 0
var shield := 0
var style := ""            # style d'attaque (PlayerStats.style) : "" coup de base, estoc, toupie, fronde, maillet
var style_reach := 1.0
var dash_hits := false     # Pantoufles-fusees
var dash_hit_ids := {}     # ennemis deja touches pendant ce dash
var box_shape: Shape2D     # forme d'origine du coup (rectangle), remise apres un estoc ou une toupie
var thrust_shape := RectangleShape2D.new()
var spin_shape := CircleShape2D.new()

func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = PlayerFrames.make()
	sprite.material = Fx.make_flash_material()
	attack_shape.disabled = true
	box_shape = attack_shape.shape
	attack_hitbox.area_entered.connect(_on_attack_area_entered)
	apply_items()
	hp = GameState.current_hp()  # les PV perdus aux combats precedents le restent

func apply_items() -> void:
	var lost := max_hp - hp
	max_hp = GameState.max_hp()
	attack_damage = PlayerStats.damage()
	move_speed = PlayerStats.move_speed()
	dash_cooldown_effective = PlayerStats.dash_cooldown()
	attack_cooldown_effective = PlayerStats.attack_cooldown()
	dash_duration = PlayerStats.dash_duration()
	reach = PlayerStats.reach()
	hurt_invincibility = PlayerStats.iframes()
	has_dash_trail = GameState.mod("dash_trail") > 0
	has_slow_on_hit = GameState.mod("slow_on_hit") > 0
	heal_on_hit_chance = PlayerStats.heal_on_hit()
	heal_on_kill_chance = PlayerStats.heal_on_kill()
	crit_chance = PlayerStats.crit()
	evasion = PlayerStats.evasion()
	knockback = PlayerStats.knockback()
	thorns = PlayerStats.thorns()
	extra_lives = PlayerStats.extra_lives()
	shield = PlayerStats.shield()
	special_cooldown_effective = PlayerStats.special_cooldown()
	style = PlayerStats.style()
	style_reach = PlayerStats.style_reach()
	dash_hits = PlayerStats.dash_hits()
	_sync_sheep()
	hp = clampi(max_hp - lost, 1, max_hp)  # un +PV max arrive plein

# Moutons gardiens : autant de moutons que l'objet en donne, repartis sur le cercle.
func _sync_sheep() -> void:
	var wanted := PlayerStats.guard_sheep()
	var flock: Array = get_children().filter(func(n): return n is GuardSheep)
	while flock.size() > wanted:
		flock.pop_back().queue_free()
	while flock.size() < wanted:
		var sheep := GuardSheep.new()
		add_child(sheep)
		flock.append(sheep)
	for i in flock.size():
		flock[i].index = i
		flock[i].count = flock.size()

func _process(delta: float) -> void:
	slash_timer = max(0.0, slash_timer - delta)
	ring_timer = max(0.0, ring_timer - delta)
	speed_boost_timer = max(0.0, speed_boost_timer - delta)
	_update_camera(delta)
	PlayerFrames.animate(sprite, velocity.length() > 10.0)
	if velocity.length() > 10.0 and not dashing:
		bob_time += delta
		sprite.position.y = round(-abs(sin(bob_time * 12.0)) * 2.0)
	else:
		sprite.position.y = 0.0
	if not dashing and not dead:
		# Clignote pendant l'invincibilite qui suit un coup.
		sprite.visible = hurt_timer <= 0.0 or int(hurt_timer * 20.0) % 2 == 0
	queue_redraw()

# Secousse (trauma) et a-coup du coup, en temps reel : elles continuent de retomber pendant l'arret
# sur image au lieu de figer la camera de travers.
func _update_camera(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.0001)
	trauma = maxf(0.0, trauma - SHAKE_DECAY * real_delta)
	kick = kick.lerp(Vector2.ZERO, 1.0 - exp(-14.0 * real_delta))
	shake_time += real_delta * 30.0
	if not Settings.enabled("screen_shake"):
		camera.offset = Vector2.ZERO
		return
	var amount := trauma * trauma
	camera.offset = kick + Vector2(SHAKE_OFFSET.x * amount * sin(shake_time * 1.7), SHAKE_OFFSET.y * amount * sin(shake_time * 2.3))

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	Controls.rumble(amount)

func _draw() -> void:
	Fx.draw_shadow(self, PlayerFrames.SHADOW_Y, 26.0)
	if slash_timer > 0.0:
		_draw_slash()
		_draw_combo()

# Le coup balaie son arc (vite au debut, puis il ralentit) et laisse une trainee qui s'eteint.
func _draw_slash() -> void:
	var t := 1.0 - slash_timer / ATTACK_DURATION  # 0 -> 1 pendant le coup
	var sweep := 1.0 - pow(1.0 - minf(t * 1.6, 1.0), 3.0)
	var fade := 1.0 - maxf(0.0, t - 0.45) / 0.55
	var angle := facing.angle()
	if style == "fronde":  # eclair au depart de la bille
		draw_circle(facing * 16.0, 7.0 * fade, Color(1, 1, 0.9, fade))
		return
	if style == "toupie":  # le coup fait le tour du joueur
		var radius := strike_reach + SPIN_EXTRA
		var turn := TAU * sweep * swing_side
		draw_arc(Vector2.ZERO, radius, angle, angle + turn, 32, Color(0.8, 0.9, 1, fade * 0.6), 7.0)
		draw_arc(Vector2.ZERO, radius, angle + turn * 0.6, angle + turn, 16, Color(1, 1, 1, fade), 4.0)
		if strike_kind == "finisher":
			draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 40, Color(1, 0.88, 0.45, fade * 0.7), 4.0)
		return
	if style == "estoc":  # longue lance droite devant soi
		var length := lerpf(strike_reach * 0.6, strike_reach * 2.0, sweep)
		var gold := strike_kind == "finisher"
		draw_line(facing * 8.0, facing * length, Color(1, 0.88, 0.45, fade) if gold else Color(0.7, 0.9, 1, fade), 9.0 if gold else 6.0)
		draw_line(facing * 12.0, facing * (length + 4.0), Color(1, 1, 1, fade), 3.0)
		return
	if strike_kind == "heavy":  # maillet : grand arc lourd et onde d'impact
		draw_arc(Vector2.ZERO, strike_reach + 14.0, angle - 1.2, angle - 1.2 + 2.4 * sweep, 18, Color(1, 0.75, 0.45, fade * 0.85), 12.0)
		draw_arc(facing * strike_reach, 26.0 * MALLET_SCALE * sweep, 0.0, TAU, 28, Color(1, 0.95, 0.8, fade * 0.7), 3.0)
		return
	if strike_kind == "dash":  # estoc : un trait qui file dans le sens du dash
		var tip := facing * lerpf(strike_reach, strike_reach + 26.0, sweep)
		draw_line(facing * 6.0, tip, Color(0.7, 0.9, 1, fade), 7.0)
		draw_line(facing * 10.0, tip + facing * 3.0, Color(1, 1, 1, fade), 3.0)
		draw_arc(Vector2.ZERO, strike_reach + 6.0, angle - 0.7, angle + 0.7, 10, Color(1, 1, 1, fade * 0.8), 4.0)
		return
	var finisher := strike_kind == "finisher"
	var half := 1.5 if finisher else 1.1
	var start := angle - half * swing_side
	var end := start + 2.0 * half * swing_side * sweep
	var trail := start + (end - start) * 0.45  # la fin du balayage, plus vive
	var from := minf(start, end)
	var to := maxf(start, end)
	var trail_from := minf(trail, end)
	var trail_to := maxf(trail, end)
	if to - from < 0.02:
		return
	if finisher:  # grand arc dore, plus large
		draw_arc(Vector2.ZERO, strike_reach + 10.0, from, to, 18, Color(1, 0.88, 0.45, fade * 0.85), 9.0)
		draw_arc(Vector2.ZERO, strike_reach + 2.0, trail_from, trail_to, 12, Color(1, 1, 1, fade), 4.0)
		draw_arc(Vector2.ZERO, strike_reach - 8.0, from, to, 14, Color(1, 0.7, 0.3, fade * 0.6), 3.0)
	else:
		draw_arc(Vector2.ZERO, strike_reach + 6.0, from, to, 14, Color(0.8, 0.9, 1, fade * 0.55), 6.0)
		draw_arc(Vector2.ZERO, strike_reach + 6.0, trail_from, trail_to, 10, Color(1, 1, 1, fade), 6.0)
		draw_arc(Vector2.ZERO, strike_reach - 2.0, from, to, 12, Color(0.7, 0.85, 1, fade * 0.6), 3.0)
	# Pointe de la lame, au bout du balayage.
	draw_circle(Vector2.from_angle(end) * (strike_reach + 6.0), 3.5 if finisher else 2.5, Color(1, 1, 1, fade))

# Enchainement en cours (un point par coup place, au-dessus de la tete) et onde de l'objet actif.
func _draw_combo() -> void:
	if combo > 0 and combo_timer > 0.0:
		for i in COMBO_FINISHER - 1:
			var at := Vector2(-5.0 + i * 10.0, -40.0)
			draw_circle(at, 3.5, Color(0.08, 0.05, 0.1, 0.8))
			draw_circle(at, 2.5, Color(1, 0.88, 0.45) if i < combo else Color(1, 1, 1, 0.25))
	if ring_timer > 0.0:
		var r := ring_radius * (1.0 - ring_timer / 0.35)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(ring_color, ring_timer / 0.35), 4.0)

func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)
	attack_cooldown_timer = max(0.0, attack_cooldown_timer - delta)
	combo_timer = max(0.0, combo_timer - delta)
	dash_strike_timer = max(0.0, dash_strike_timer - delta)
	since_dash += delta
	attack_buffer = maxf(0.0, attack_buffer - delta)
	special_timer = maxf(0.0, special_timer - delta)
	special_buffer = maxf(0.0, special_buffer - delta)
	if special_buffer > 0.0 and special_timer <= 0.0:
		special_buffer = 0.0
		_try_special()
	dash_buffer = maxf(0.0, dash_buffer - delta)
	if attack_buffer > 0.0 and attack_cooldown_timer <= 0.0:
		attack_buffer = 0.0
		_try_attack()
	if hurt_timer > 0.0:
		hurt_timer -= delta
		if hurt_timer <= 0.0 and not dashing:
			invincible = false

	var input_vector := Controls.move_vector()
	if input_vector.length() > 0.1:
		facing = input_vector.normalized()
		if abs(facing.x) > 0.1:
			sprite.flip_h = facing.x < 0

	if dashing:
		dash_timer -= delta
		dash_ghost_timer -= delta
		if dash_ghost_timer <= 0.0:
			dash_ghost_timer = DASH_GHOST_EVERY
			Fx.ghost(sprite, Color(0.6, 0.8, 1, 0.55), 0.22)
		if dash_hits:
			_dash_hit()
		if has_dash_trail:
			dash_trail_timer -= delta
			if dash_trail_timer <= 0.0:
				dash_trail_timer = 0.05
				_spawn_dash_trail()
		if dash_timer <= 0.0:
			dashing = false
			since_dash = 0.0
			invincible = hurt_timer > 0.0
			modulate.a = 1.0
			move_velocity = facing * move_speed  # on sort du dash en courant, sans a-coup
			_squash(Vector2(0.85, 1.15), 0.16)  # il se pose
		velocity = facing * DASH_SPEED
	else:
		if (Input.is_action_pressed("dash") or dash_buffer > 0.0) and dash_cooldown_timer <= 0.0:
			dash_buffer = 0.0
			_start_dash()
		var target := input_vector * move_speed * (CAFE_SPEED_MULT if speed_boost_timer > 0.0 else 1.0)
		move_velocity = move_velocity.move_toward(target, (ACCELERATION if target != Vector2.ZERO else FRICTION) * delta)
		velocity = move_velocity
		if slow_timer > 0.0:
			velocity *= slow_factor
		velocity += external_velocity  # le dash permet d'echapper a une attraction
	external_velocity = Vector2.ZERO
	slow_timer = maxf(0.0, slow_timer - delta)
	sprite.self_modulate = Color(0.7, 0.75, 1.0) if slow_timer > 0.0 else Color.WHITE

	move_and_slide()

func add_external_velocity(v: Vector2) -> void:
	external_velocity += v

func apply_slow(duration: float, factor: float) -> void:
	slow_timer = maxf(slow_timer, duration)
	slow_factor = factor

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event.is_action_pressed("attack"):
		if attack_cooldown_timer > 0.0:
			attack_buffer = ATTACK_BUFFER  # partira des que possible
		else:
			_try_attack()
	elif event.is_action_pressed("dash"):
		dash_buffer = DASH_BUFFER
	elif event.is_action_pressed("special"):
		if special_timer > 0.0:
			special_buffer = ATTACK_BUFFER
		else:
			_try_special()
	elif event.is_action_pressed("active"):
		_use_active_item()

func _start_dash() -> void:
	Sound.play("dash")
	dashing = true
	invincible = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown_effective
	dash_trail_timer = 0.0
	dash_ghost_timer = 0.0
	dash_hit_ids.clear()
	modulate.a = 0.5
	_squash(Vector2(1.3, 0.75), 0.12)  # il s'etire dans l'elan

# Pantoufles-fusees : chaque ennemi touche pendant le dash prend un coup (une fois par dash),
# et le dash se recharge presque aussitot.
func _dash_hit() -> void:
	for mob in _mobs_within(DASH_HIT_RADIUS):
		var hurtbox: Node = mob.get_node_or_null("Hurtbox")
		if hurtbox == null or dash_hit_ids.has(mob.get_instance_id()):
			continue
		dash_hit_ids[mob.get_instance_id()] = true
		apply_hit(hurtbox, attack_damage, false, facing)
		dash_cooldown_timer = minf(dash_cooldown_timer, dash_cooldown_effective * DASH_HIT_REFUND)

# Etirement / ecrasement du sprite (visuel seulement), qui revient a sa taille en rebondissant.
func _squash(amount: Vector2, duration: float) -> void:
	if squash_tween:
		squash_tween.kill()
	sprite.scale = SPRITE_SCALE * amount
	squash_tween = sprite.create_tween()
	squash_tween.tween_property(sprite, "scale", SPRITE_SCALE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_dash_trail() -> void:
	var trail: Area2D = DashTrailScene.instantiate()
	get_tree().current_scene.add_child(trail)
	trail.global_position = global_position

func _try_attack() -> void:
	if attack_cooldown_timer > 0.0:
		return
	var mallet := style == "maillet"  # pas d'enchainement : chaque coup est lourd
	combo = 1 if mallet else (combo + 1 if combo_timer > 0.0 else 1)
	var finisher := not mallet and combo >= COMBO_FINISHER
	var dash_strike := dash_strike_timer <= 0.0 and (dashing or since_dash <= DASH_STRIKE_WINDOW)
	if dash_strike:
		dash_strike_timer = DASH_STRIKE_COOLDOWN
	strike_kind = "heavy" if mallet else ("finisher" if finisher else ("dash" if dash_strike else ""))
	strike_damage = attack_damage * (2 if finisher or mallet else 1) + (1 if dash_strike else 0)
	strike_reach = (reach + (FINISHER_REACH if finisher else 0.0) + (DASH_STRIKE_REACH if dash_strike else 0.0)) * style_reach
	attack_cooldown_timer = attack_cooldown_effective * (FINISHER_RECOVERY if finisher else 1.0)
	combo_timer = 0.0 if finisher or mallet else attack_cooldown_effective + COMBO_WINDOW
	if finisher or mallet:
		combo = 0
	swing_side = 1.0 if finisher else -swing_side
	if finisher and GameState.mod("finisher_volley") > 0.0:
		_volley()  # Bouquet final : le coup final lance une rafale, sans toucher a sa recharge
	_squash(Vector2(1.12, 0.9) if finisher else Vector2(1.06, 0.95), 0.12)
	Sound.play("slash")
	slash_timer = ATTACK_DURATION
	last_attack_time = Time.get_ticks_msec() / 1000.0
	if style == "fronde":  # pas de coup au corps a corps : une bille (trois au 3e coup)
		_shoot_pellets(finisher)
		attacked.emit(global_position + facing * strike_reach)
		return
	_shape_strike(finisher, dash_strike)
	attacked.emit(attack_hitbox.global_position)
	attack_shape.disabled = false
	await get_tree().create_timer(ATTACK_DURATION, false).timeout
	attack_shape.disabled = true

# Forme et place de la zone de frappe selon le style.
func _shape_strike(finisher: bool, dash_strike: bool) -> void:
	attack_hitbox.rotation = 0.0
	match style:
		"estoc":  # une lance : un long rectangle dans l'axe du coup
			thrust_shape.size = Vector2(strike_reach * 2.0, THRUST_WIDTH * (1.4 if finisher else 1.0))
			attack_shape.shape = thrust_shape
			attack_hitbox.position = facing * strike_reach
			attack_hitbox.rotation = facing.angle()
			attack_hitbox.scale = Vector2.ONE
		"toupie":  # un disque autour du joueur
			spin_shape.radius = strike_reach + SPIN_EXTRA + (10.0 if finisher else 0.0)
			attack_shape.shape = spin_shape
			attack_hitbox.position = Vector2.ZERO
			attack_hitbox.scale = Vector2.ONE
		_:
			attack_shape.shape = box_shape
			attack_hitbox.position = facing * strike_reach
			var size := MALLET_SCALE if style == "maillet" else (1.45 if finisher else (1.2 if dash_strike else 1.0))
			attack_hitbox.scale = Vector2.ONE * size

# Fronde : la bille part devant ; au 3e coup, trois billes en eventail.
func _shoot_pellets(finisher: bool) -> void:
	var shot := {}
	for offset in ([-PELLET_SPREAD, 0.0, PELLET_SPREAD] if finisher else [0.0]):
		var pellet := Pellet.new()
		pellet.direction = facing.rotated(offset)
		pellet.damage = strike_damage
		pellet.heavy = finisher
		pellet.reach = PELLET_RANGE + (reach - ATTACK_REACH) * 3.0
		pellet.shooter = self
		pellet.shot = shot
		pellet.position = global_position + pellet.direction * 16.0
		get_parent().add_child(pellet)

# Rafale de plumes : l'attaque speciale, a distance. En eventail devant soi, ou tout autour avec
# la Tempete de plumes (ensemble Plumier + Plume de paon).
func _try_special() -> bool:
	if special_timer > 0.0 or dead:
		return false
	special_timer = special_cooldown_effective
	_volley()
	special_used.emit()
	return true

func _volley() -> void:
	var count := PlayerStats.feathers()
	var storm := PlayerStats.feather_storm()
	var directions := []
	if storm:
		count = maxi(count + 3, 8)
		for i in count:
			directions.append(facing.rotated(TAU * i / count))
	else:
		var spread := 0.22 * (count - 1)  # environ 12 degres entre deux plumes
		for i in count:
			directions.append(facing.rotated(-spread / 2.0 + spread * i / maxf(count - 1, 1)))
	var volley := {}
	for direction in directions:
		var feather := Feather.new()
		feather.direction = direction
		feather.damage = attack_damage
		feather.pierce = PlayerStats.feather_pierce()
		feather.volley = volley
		feather.position = global_position + direction * 14.0
		get_parent().add_child(feather)
	Sound.play("slash", -2.0)
	_squash(Vector2(0.9, 1.1), 0.14)
	add_trauma(0.12)

func _use_active_item() -> void:
	if not GameState.has_active_item():
		item_message.emit("Aucun objet actif")
		return
	if GameState.active_charges <= 0:
		item_message.emit("Plus de charge : gagne un combat pour recharger")
		return
	var item_name: String = Items.find_active(GameState.active_item_id)["name"]
	match GameState.active_item_id:
		"sept_ans_de_malheur":
			_use_sept_ans_de_malheur()
		"mouchoir_usage":
			if hp >= max_hp:
				item_message.emit("PV déjà au maximum")
				return
			_heal(1)
		"reveil_strident":
			_use_reveil_strident()
		"oreiller_volant":
			_use_oreiller_volant()
		"tasse_de_cafe":
			dash_cooldown_timer = 0.0
			speed_boost_timer = CAFE_DURATION
			Fx.flash(sprite, Color(0.9, 0.7, 0.4), 0.3)
	GameState.active_charges -= 1
	Sound.play("active")
	item_message.emit("%s ! (%d charge(s) restante(s))" % [item_name, GameState.active_charges])

func _use_sept_ans_de_malheur() -> void:
	var decoy: Node2D = MirrorDecoyScene.instantiate()
	get_tree().current_scene.add_child(decoy)
	decoy.global_position = global_position
	invincible = true
	Fx.flash(sprite, Color(0.8, 0.9, 1.0), 0.4)
	await get_tree().create_timer(decoy.DURATION, false).timeout
	if not dashing and hurt_timer <= 0.0:
		invincible = false

func _use_reveil_strident() -> void:
	_ring(Color(1, 0.95, 0.5), REVEIL_RADIUS)
	for mob in _mobs_within(REVEIL_RADIUS):
		mob.stun(1.2)

func _use_oreiller_volant() -> void:
	_ring(Color(1, 1, 1), OREILLER_RADIUS)
	for mob in _mobs_within(OREILLER_RADIUS):
		mob.take_hit(OREILLER_DAMAGE * attack_damage)

func _ring(color: Color, radius: float) -> void:
	ring_color = color
	ring_radius = radius
	ring_timer = 0.35
	add_trauma(0.45)

func _mobs_within(radius: float) -> Array:
	return get_tree().get_nodes_in_group("mobs").filter(func(mob): return global_position.distance_to(mob.global_position) <= radius)

# Appele par l'arene a chaque ennemi tue.
func on_enemy_killed() -> void:
	if heal_on_kill_chance > 0.0 and hp < max_hp and randf() < heal_on_kill_chance:
		_heal(1)

func _heal(amount: int) -> void:
	Sound.play("heal")
	hp = min(max_hp, hp + amount)
	hp_changed.emit(hp)
	Fx.flash(sprite, Color(0.5, 1.0, 0.6), 0.3)

func _on_attack_area_entered(area: Area2D) -> void:
	apply_hit(area, strike_damage, strike_kind == "finisher" or strike_kind == "heavy", facing)

# Un coup du joueur (corps a corps, bille, dash) : critique, son, secousse, recul, ralentissement,
# soin. heavy : coup fort (3e coup, maillet).
func apply_hit(area: Node, damage: int, heavy: bool, direction: Vector2) -> void:
	if not area.has_method("register_hit"):
		return
	var crit := randf() < crit_chance
	var strong := crit or heavy
	area.register_hit(damage * (2 if crit else 1))
	Sound.play("crit" if strong else "hit")
	add_trauma(0.32 if strong else 0.16)
	kick = direction * (4.0 if strong else 2.0)
	Fx.hitstop(get_tree(), 0.075 if strong else 0.035)
	var target := area.get_parent()
	var mallet := heavy and style == "maillet"
	var push_force := knockback + (MALLET_PUSH if mallet else 0.0)
	if push_force > 0.0 and is_instance_valid(target) and target is CharacterBody2D:
		var push: Vector2 = (target.global_position - global_position).normalized() * push_force
		if target.has_method("knock"):
			target.knock(push)
		else:
			target.move_and_collide(push)
	var mob := target as BaseMob
	if mallet and mob != null and not mob.is_boss and mob.state != BaseMob.State.DEAD:
		mob.stun(MALLET_STUN)
	if has_slow_on_hit and is_instance_valid(target) and target.has_method("apply_slow"):
		target.apply_slow(1.0, 0.5)
	if heal_on_hit_chance > 0.0 and hp < max_hp and randf() < heal_on_hit_chance:
		_heal(1)

# amount : degats du coup (1 en general) ; la malediction "Coeur fele" en ajoute.
func take_damage(amount: int = 1) -> void:
	if invincible or dead:
		return
	amount += int(GameState.mod("enemy_damage"))
	if randf() < evasion:
		Sound.play("dodge")
		Fx.flash(sprite, Color(0.6, 0.9, 1), 0.2)
		_start_hurt_invincibility()
		return
	if shield > 0:
		Sound.play("shield")
		shield -= 1
		Fx.flash(sprite, Color(1, 0.9, 0.5), 0.3)
		_start_hurt_invincibility()
		item_message.emit("Doudou protecteur : coup bloqué !")
		return
	add_trauma(0.55)
	Sound.play("hurt")
	Fx.flash(sprite, Color(1, 0.3, 0.3), 0.2)
	if thorns > 0:
		for mob in _mobs_within(THORNS_RADIUS):
			mob.take_hit(thorns)
	if hp <= amount and extra_lives > 0:
		extra_lives -= 1
		hp = maxi(1, hp - amount + 1)  # survit avec 1 PV
		hp_changed.emit(hp)
		_start_hurt_invincibility()
		item_message.emit("Croque-mort au chômage : tu survis !")
		return
	hp -= amount
	hp_changed.emit(hp)
	if hp <= 0:
		_die()
		return
	_start_hurt_invincibility()

func _start_hurt_invincibility() -> void:
	invincible = true
	hurt_timer = hurt_invincibility

func _die() -> void:
	Sound.play("death")
	dead = true
	invincible = true
	dashing = false
	sprite.visible = true
	modulate = Color(1, 0.3, 0.3, 1)
	died.emit()
