extends CharacterBody2D

signal hp_changed(hp: int)
signal died

const SPEED := 200.0
const DASH_SPEED := 600.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 0.6
const ATTACK_DURATION := 0.15
const ATTACK_COOLDOWN := 0.35
const MAX_HP := 3

@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var facing := Vector2.DOWN
var invincible := false
var dashing := false
var dead := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var attack_cooldown_timer := 0.0
var hp := MAX_HP

func _ready() -> void:
	add_to_group("player")
	attack_shape.disabled = true
	attack_hitbox.area_entered.connect(_on_attack_area_entered)

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
	if event is InputEventKey and event.physical_keycode == KEY_SPACE and event.pressed and not event.echo:
		_try_attack()

func _start_dash() -> void:
	dashing = true
	invincible = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	modulate.a = 0.5

func _try_attack() -> void:
	if attack_cooldown_timer > 0.0:
		return
	attack_cooldown_timer = ATTACK_COOLDOWN
	attack_hitbox.position = facing * 30
	attack_shape.disabled = false
	await get_tree().create_timer(ATTACK_DURATION).timeout
	attack_shape.disabled = true

func _on_attack_area_entered(area: Area2D) -> void:
	if area.has_method("register_hit"):
		area.register_hit()

func take_damage() -> void:
	if invincible or dead:
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
