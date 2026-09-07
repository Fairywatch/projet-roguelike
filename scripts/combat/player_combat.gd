extends CharacterBody2D

signal hp_changed(hp: int)
signal died
signal item_message(text: String)

const SPEED := 200.0
const DASH_SPEED := 600.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN_BASE := 0.6
const ATTACK_DURATION := 0.15
const ATTACK_COOLDOWN := 0.35
const BASE_MAX_HP := 3
const HEAL_ON_HIT_CHANCE_PER_STACK := 0.15
const DASH_COOLDOWN_MULT_PER_STACK := 0.85

const DashTrailScene := preload("res://scenes/combat/DashTrail.tscn")
const MirrorDecoyScene := preload("res://scenes/combat/MirrorDecoy.tscn")

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

var max_hp := BASE_MAX_HP
var hp := BASE_MAX_HP
var attack_damage := 1
var dash_cooldown_effective := DASH_COOLDOWN_BASE
var has_dash_trail := false
var has_slow_on_hit := false
var heal_on_hit_chance := 0.0
var extra_lives := 0

func _ready() -> void:
	add_to_group("player")
	attack_shape.disabled = true
	attack_hitbox.area_entered.connect(_on_attack_area_entered)
	_apply_all_passive_items()
	hp = max_hp

func _apply_all_passive_items() -> void:
	max_hp = BASE_MAX_HP
	attack_damage = 1
	dash_cooldown_effective = DASH_COOLDOWN_BASE
	has_dash_trail = false
	has_slow_on_hit = false
	heal_on_hit_chance = 0.0
	extra_lives = 0
	for id in GameState.passive_items.keys():
		var count: int = GameState.passive_items[id]
		_apply_passive_stack(id, count)

func _apply_passive_stack(id: String, count: int) -> void:
	match id:
		"plume_de_reve":
			max_hp += count
		"sablier_fele":
			dash_cooldown_effective = DASH_COOLDOWN_BASE * pow(DASH_COOLDOWN_MULT_PER_STACK, count)
		"larme_de_crocodile":
			heal_on_hit_chance = HEAL_ON_HIT_CHANCE_PER_STACK * count
		"coup_de_barre":
			has_dash_trail = true
		"grelot_du_sommeil":
			has_slow_on_hit = true
		"pacte_dombre":
			attack_damage += count
			max_hp = max(1, max_hp - count)
		"croque_mort_au_chomage":
			extra_lives += count

func obtain_item(id: String) -> void:
	var is_active: bool = not Items.find_active(id).is_empty()
	if is_active:
		GameState.set_active_item(id)
	else:
		GameState.add_passive_item(id)
		_apply_all_passive_items()
		hp = min(hp, max_hp)
	var item := Items.find(id)
	item_message.emit("Objet obtenu : %s" % item.get("name", id))

func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)
	attack_cooldown_timer = max(0.0, attack_cooldown_timer - delta)

	var input_vector := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	if input_vector.length() > 0.1:
		facing = input_vector.normalized()

	if dashing:
		dash_timer -= delta
		if has_dash_trail:
			dash_trail_timer -= delta
			if dash_trail_timer <= 0.0:
				dash_trail_timer = 0.05
				_spawn_dash_trail()
		if dash_timer <= 0.0:
			dashing = false
			invincible = false
			modulate.a = 1.0
		velocity = facing * DASH_SPEED
	else:
		if Input.is_physical_key_pressed(KEY_SHIFT) and dash_cooldown_timer <= 0.0:
			_start_dash()
		velocity = input_vector * SPEED

	move_and_slide()

func _unhandled_key_input(event: InputEvent) -> void:
	if dead:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_SPACE:
		_try_attack()
	elif event.physical_keycode == KEY_E:
		_use_active_item()

func _start_dash() -> void:
	dashing = true
	invincible = true
	dash_timer = DASH_DURATION
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
	attack_cooldown_timer = ATTACK_COOLDOWN
	attack_hitbox.position = facing * 30
	attack_shape.disabled = false
	await get_tree().create_timer(ATTACK_DURATION).timeout
	attack_shape.disabled = true

func _use_active_item() -> void:
	if GameState.active_item_id == "" or GameState.active_charges <= 0:
		return
	GameState.active_charges -= 1
	match GameState.active_item_id:
		"sept_ans_de_malheur":
			_use_sept_ans_de_malheur()
		"mouchoir_usage":
			_use_mouchoir_usage()
		"reveil_strident":
			_use_reveil_strident()

func _use_sept_ans_de_malheur() -> void:
	var decoy: Node2D = MirrorDecoyScene.instantiate()
	get_tree().current_scene.add_child(decoy)
	decoy.global_position = global_position
	invincible = true
	await get_tree().create_timer(1.5).timeout
	if not dashing:
		invincible = false

func _use_mouchoir_usage() -> void:
	if hp < max_hp:
		hp += 1
		hp_changed.emit(hp)

func _use_reveil_strident() -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		if global_position.distance_to(mob.global_position) <= 220.0:
			mob.stun(1.2)

func _on_attack_area_entered(area: Area2D) -> void:
	if area.has_method("register_hit"):
		area.register_hit(attack_damage)
	if has_slow_on_hit and area.get_parent() and area.get_parent().has_method("apply_slow"):
		area.get_parent().apply_slow(1.0, 0.5)
	if heal_on_hit_chance > 0.0 and hp < max_hp and randf() < heal_on_hit_chance:
		hp += 1
		hp_changed.emit(hp)

func take_damage() -> void:
	if invincible or dead:
		return
	if hp <= 1 and extra_lives > 0:
		extra_lives -= 1
		return
	hp -= 1
	hp_changed.emit(hp)
	if hp <= 0:
		_die()

func _die() -> void:
	dead = true
	invincible = true
	dashing = false
	modulate = Color(1, 0.3, 0.3, 1)
	died.emit()
