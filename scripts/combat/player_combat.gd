extends CharacterBody2D

signal hp_changed(hp: int)
signal died
signal item_message(text: String)
# Chaque attaque du joueur, avec la position de son coup (l'Echo la repete, l'Autre Soi l'observe).
signal attacked(at: Vector2)

const SPEED := 200.0
const DASH_SPEED := 600.0
# Prise de vitesse et freinage tres courts (~0,08 s et ~0,1 s) : du liant sans perdre en reactivite.
const ACCELERATION := 2600.0
const FRICTION := 2000.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN_BASE := 0.6
const ATTACK_DURATION := 0.15
const ATTACK_COOLDOWN := 0.35
const ATTACK_REACH := 30.0
const HURT_INVINCIBILITY := 0.8
const MIN_COOLDOWN_MULT := 0.3
const MIN_SPEED_MULT := 0.5
const MAX_EVASION := 0.5
const REVEIL_RADIUS := 220.0
const OREILLER_RADIUS := 150.0
const OREILLER_DAMAGE := 2
const THORNS_RADIUS := 90.0
const CAFE_DURATION := 4.0
const CAFE_SPEED_MULT := 1.5

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
var shake := 0.0
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

func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = PlayerFrames.make()
	sprite.material = Fx.make_flash_material()
	attack_shape.disabled = true
	attack_hitbox.area_entered.connect(_on_attack_area_entered)
	apply_items()
	hp = GameState.current_hp()  # les PV perdus aux combats precedents le restent

func apply_items() -> void:
	var lost := max_hp - hp
	max_hp = GameState.max_hp()
	attack_damage = 1 + int(GameState.mod("damage"))
	move_speed = SPEED * maxf(MIN_SPEED_MULT, 1.0 + GameState.mod("speed"))
	dash_cooldown_effective = DASH_COOLDOWN_BASE * maxf(MIN_COOLDOWN_MULT, 1.0 + GameState.mod("dash_cooldown"))
	attack_cooldown_effective = ATTACK_COOLDOWN * maxf(MIN_COOLDOWN_MULT, 1.0 + GameState.mod("attack_cooldown"))
	dash_duration = DASH_DURATION * (1.0 + GameState.mod("dash_length"))
	reach = ATTACK_REACH + GameState.mod("reach")
	hurt_invincibility = HURT_INVINCIBILITY + GameState.mod("iframes")
	has_dash_trail = GameState.mod("dash_trail") > 0
	has_slow_on_hit = GameState.mod("slow_on_hit") > 0
	heal_on_hit_chance = GameState.mod("heal_on_hit")
	heal_on_kill_chance = GameState.mod("heal_on_kill")
	crit_chance = GameState.mod("crit")
	evasion = minf(MAX_EVASION, GameState.mod("evasion"))
	knockback = GameState.mod("knockback")
	thorns = int(GameState.mod("thorns"))
	extra_lives = int(GameState.mod("extra_lives"))
	shield = int(GameState.mod("shield"))
	hp = clampi(max_hp - lost, 1, max_hp)  # un +PV max arrive plein

func _process(delta: float) -> void:
	slash_timer = max(0.0, slash_timer - delta)
	ring_timer = max(0.0, ring_timer - delta)
	speed_boost_timer = max(0.0, speed_boost_timer - delta)
	shake = move_toward(shake, 0.0, delta * 30.0)
	var amount := shake if Settings.enabled("screen_shake") else 0.0
	camera.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
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

func _draw() -> void:
	Fx.draw_shadow(self, PlayerFrames.SHADOW_Y, 26.0)
	if slash_timer > 0.0:
		var t := slash_timer / ATTACK_DURATION
		var angle := facing.angle()
		draw_arc(Vector2.ZERO, reach + 6.0, angle - 1.1, angle + 1.1, 12, Color(1, 1, 1, t), 6.0)
		draw_arc(Vector2.ZERO, reach - 2.0, angle - 0.8, angle + 0.8, 10, Color(0.7, 0.85, 1, t * 0.7), 3.0)
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
		if has_dash_trail:
			dash_trail_timer -= delta
			if dash_trail_timer <= 0.0:
				dash_trail_timer = 0.05
				_spawn_dash_trail()
		if dash_timer <= 0.0:
			dashing = false
			invincible = hurt_timer > 0.0
			modulate.a = 1.0
			move_velocity = facing * move_speed  # on sort du dash en courant, sans a-coup
		velocity = facing * DASH_SPEED
	else:
		if Input.is_action_pressed("dash") and dash_cooldown_timer <= 0.0:
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
		_try_attack()
	elif event.is_action_pressed("active"):
		_use_active_item()

func _start_dash() -> void:
	Sound.play("dash")
	dashing = true
	invincible = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown_effective
	dash_trail_timer = 0.0
	modulate.a = 0.5

func _spawn_dash_trail() -> void:
	var trail: Area2D = DashTrailScene.instantiate()
	get_tree().current_scene.add_child(trail)
	trail.global_position = global_position

func _try_attack() -> void:
	if attack_cooldown_timer > 0.0:
		return
	attack_cooldown_timer = attack_cooldown_effective
	Sound.play("slash")
	slash_timer = ATTACK_DURATION
	attack_hitbox.position = facing * reach
	last_attack_time = Time.get_ticks_msec() / 1000.0
	attacked.emit(attack_hitbox.global_position)
	attack_shape.disabled = false
	await get_tree().create_timer(ATTACK_DURATION, false).timeout
	attack_shape.disabled = true

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
		mob.take_hit(OREILLER_DAMAGE)

func _ring(color: Color, radius: float) -> void:
	ring_color = color
	ring_radius = radius
	ring_timer = 0.35
	shake = 5.0

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
	if area.has_method("register_hit"):
		var crit := randf() < crit_chance
		area.register_hit(attack_damage * (2 if crit else 1))
		Sound.play("crit" if crit else "hit")
		shake = max(shake, 5.0 if crit else 2.5)
		Fx.hitstop(get_tree(), 0.08 if crit else 0.04)
		var target := area.get_parent()
		if knockback > 0.0 and is_instance_valid(target) and target is CharacterBody2D:
			target.move_and_collide((target.global_position - global_position).normalized() * knockback)
	if has_slow_on_hit and area.get_parent() and area.get_parent().has_method("apply_slow"):
		area.get_parent().apply_slow(1.0, 0.5)
	if heal_on_hit_chance > 0.0 and hp < max_hp and randf() < heal_on_hit_chance:
		_heal(1)

func take_damage() -> void:
	if invincible or dead:
		return
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
	shake = 7.0
	Sound.play("hurt")
	Fx.flash(sprite, Color(1, 0.3, 0.3), 0.2)
	if thorns > 0:
		for mob in _mobs_within(THORNS_RADIUS):
			mob.take_hit(thorns)
	if hp <= 1 and extra_lives > 0:
		extra_lives -= 1
		_start_hurt_invincibility()
		item_message.emit("Croque-mort au chômage : tu survis !")
		return
	hp -= 1
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
