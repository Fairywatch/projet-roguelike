extends CharacterBody2D
class_name BaseMob

signal died
signal hp_changed(hp: int)

var chase_speed := 70.0
var attack_range := 55.0
var telegraph_duration := 0.6
var attack_duration := 0.2
var cooldown_duration := 0.8

enum State { CHASE, TELEGRAPH, ATTACK, COOLDOWN, DEAD }

@onready var sprite: Sprite2D = $Sprite

var state := State.CHASE
var hp := 3
var base_color: Color
var player: Node2D

func _ready() -> void:
	base_color = sprite.modulate
	player = get_tree().get_first_node_in_group("player")
	_on_ready()

func _on_ready() -> void:
	pass

func empower_as_guardian() -> void:
	hp = 9
	chase_speed *= 1.6
	attack_range *= 1.25
	telegraph_duration *= 0.7
	attack_duration *= 1.2
	cooldown_duration *= 0.65
	base_color = Color(0.55, 0.1, 0.65, 1)
	sprite.modulate = base_color
	sprite.scale = sprite.scale * 1.5
	var bigger_shape := RectangleShape2D.new()
	bigger_shape.size = Vector2(56, 56)
	$CollisionShape2D.shape = bigger_shape
	$Hurtbox/CollisionShape2D.shape = bigger_shape

func _physics_process(_delta: float) -> void:
	if state == State.DEAD or player == null:
		return
	if state == State.CHASE:
		var to_player := player.global_position - global_position
		if to_player.length() <= attack_range:
			velocity = Vector2.ZERO
			_start_telegraph()
		else:
			velocity = _chase_velocity(to_player)
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _chase_velocity(to_player: Vector2) -> Vector2:
	return to_player.normalized() * chase_speed

func _start_telegraph() -> void:
	state = State.TELEGRAPH
	sprite.modulate = Color(1, 0.85, 0.2, 1)
	_on_telegraph_begin()
	await get_tree().create_timer(telegraph_duration).timeout
	if state == State.DEAD:
		return
	_start_attack()

func _on_telegraph_begin() -> void:
	pass

func _start_attack() -> void:
	state = State.ATTACK
	sprite.modulate = Color(0.9, 0.1, 0.1, 1)
	_on_attack_begin()
	await get_tree().create_timer(attack_duration).timeout
	if state == State.DEAD:
		return
	_on_attack_end()
	_start_cooldown()

func _on_attack_begin() -> void:
	pass

func _on_attack_end() -> void:
	pass

func _start_cooldown() -> void:
	state = State.COOLDOWN
	sprite.modulate = base_color
	await get_tree().create_timer(cooldown_duration).timeout
	if state == State.DEAD:
		return
	state = State.CHASE

func take_hit() -> void:
	if state == State.DEAD:
		return
	hp -= 1
	hp_changed.emit(hp)
	if hp <= 0:
		_die()
		return
	var flash_from := sprite.modulate
	sprite.modulate = Color(1, 1, 1, 1)
	await get_tree().create_timer(0.08).timeout
	if state != State.DEAD:
		sprite.modulate = flash_from

func _die() -> void:
	state = State.DEAD
	_on_death()
	died.emit()
	queue_free()

func _on_death() -> void:
	pass
