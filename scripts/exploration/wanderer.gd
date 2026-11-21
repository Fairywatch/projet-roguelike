class_name DreamWanderer
extends CharacterBody2D

# Cauchemar errant, sur la carte : il remplace les rencontres invisibles. Il erre au hasard et
# fonce sur le reveur s'il le voit (un cone devant lui, ou tout pres, et pas a travers les murs).
# Le toucher lance un combat dont il prend la tete. Le prendre a revers (il ne t'a pas vu, ou il
# dort pres d'une horloge) : embuscade, les ennemis commencent etourdis. On peut aussi le semer :
# le reveur court plus vite que lui.

signal caught(wanderer: DreamWanderer, ambush: bool)

const WANDER_SPEED := 45.0
const CHASE_SPEED := 125.0  # le reveur court a 220
const SIGHT_RANGE := 150.0
const SIGHT_ANGLE := 0.75   # demi-angle du cone de vue (radians)
const HEARING := 46.0       # tout pres, il sent le reveur meme de dos
const GIVE_UP := 2.5        # secondes sans le voir avant d'abandonner la poursuite
const GRACE := 1.5          # a l'arrivee sur l'etage, il ne voit rien encore
const TOUCH := 26.0
const TINT := Color(0.6, 0.5, 0.8, 0.92)
const CONE_COLOR := Color(1, 0.95, 0.8, 0.07)
const CHASE_COLOR := Color(1, 0.35, 0.35, 0.1)

enum Mode { WANDER, CHASE, SLEEP }

var path := ""  # creature du bestiaire qu'il incarne ("lundi/mouton")
var map: Node
var player: Node2D
var cells: Array = []  # cases de sol (Vector2i) ou il peut aller
var sprite := Sprite2D.new()
var mode := Mode.WANDER
var facing := Vector2.RIGHT
var target := Vector2.ZERO
var retarget := 0.0
var lost_time := 0.0
var grace := GRACE
var alert := 0.0  # le "!" qui surgit quand il te repere
var bob := randf() * TAU
var done := false

func _ready() -> void:
	add_to_group("wanderers")
	collision_layer = 0
	collision_mask = 1  # les murs
	motion_mode = MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 10.0
	add_child(shape)
	var mob := Bestiary.make(path)
	sprite.texture = load(mob._texture_path())
	mob.free()
	sprite.hframes = BaseMob.ANIM_FRAMES
	sprite.scale = Vector2(2, 2)
	sprite.modulate = TINT
	add_child(sprite)
	if player:
		add_collision_exception_with(player)
	facing = Vector2.from_angle(randf() * TAU)
	_pick_target()

# Pression de la nuit (regle du mardi, Veilleuse...) : plus forte, il voit plus loin et court plus vite.
func _pressure() -> float:
	return map.pressure() if map and map.has_method("pressure") else 1.0

func _physics_process(delta: float) -> void:
	if done or player == null:
		return
	grace = maxf(0.0, grace - delta)
	alert = maxf(0.0, alert - delta)
	var sleeping: bool = map != null and map.get("encounter_pause") != null and map.encounter_pause > 0.0
	if sleeping:
		mode = Mode.SLEEP
	elif mode == Mode.SLEEP:
		mode = Mode.WANDER
	var to_player := player.global_position - global_position
	if to_player.length() < TOUCH and not player.frozen:
		done = true
		caught.emit(self, mode != Mode.CHASE)
		return
	var pressure := _pressure()
	match mode:
		Mode.SLEEP:
			velocity = Vector2.ZERO
		Mode.WANDER:
			if grace <= 0.0 and _sees(to_player, pressure):
				mode = Mode.CHASE
				alert = 0.6
				lost_time = 0.0
			retarget -= delta
			var to_target := target - global_position
			if to_target.length() < 8.0 or retarget <= 0.0:
				_pick_target()
				to_target = target - global_position
			velocity = to_target.normalized() * WANDER_SPEED * sqrt(pressure)
		Mode.CHASE:
			if _sees(to_player, pressure, true):
				lost_time = 0.0
			else:
				lost_time += delta
				if lost_time >= GIVE_UP:
					mode = Mode.WANDER
					_pick_target()
			velocity = to_player.normalized() * CHASE_SPEED * minf(1.3, sqrt(pressure))
	if velocity.length() > 1.0:
		facing = facing.lerp(velocity.normalized(), minf(1.0, delta * 6.0)).normalized()
	move_and_slide()
	if mode == Mode.WANDER and get_slide_collision_count() > 0:
		_pick_target()

# Dans le cone devant lui (ou tout pres), assez pres, et sans mur entre les deux.
func _sees(to_player: Vector2, pressure: float, chasing: bool = false) -> bool:
	var distance := to_player.length()
	var reach := SIGHT_RANGE * sqrt(pressure) * (1.4 if chasing else 1.0)
	if distance > reach:
		return false
	if distance > HEARING and not chasing and absf(facing.angle_to(to_player)) > SIGHT_ANGLE:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1, [get_rid(), player.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _pick_target() -> void:
	retarget = randf_range(2.0, 4.0)
	if cells.is_empty():
		target = global_position
		return
	var here := Vector2i((global_position / FloorGenerator.CELL_SIZE).floor())
	var near := cells.filter(func(c: Vector2i): return absi(c.x - here.x) <= 3 and absi(c.y - here.y) <= 3)
	var cell: Vector2i = (near if not near.is_empty() else cells).pick_random()
	target = (Vector2(cell) + Vector2(0.5, 0.5)) * FloorGenerator.CELL_SIZE

func _process(delta: float) -> void:
	bob += delta
	sprite.frame = int(bob * BaseMob.ANIM_FPS) % BaseMob.ANIM_FRAMES
	sprite.position.y = round(sin(bob * 4.0) * 2.0) - 4.0
	sprite.flip_h = facing.x < 0.0
	queue_redraw()

func _draw() -> void:
	var half: float = sprite.texture.get_height() if sprite.texture else 16.0
	# Cone de vue, discret : on lit d'ou il regarde pour le prendre a revers.
	if mode != Mode.SLEEP:
		var reach := SIGHT_RANGE * sqrt(_pressure()) * (1.4 if mode == Mode.CHASE else 1.0)
		var points := PackedVector2Array([Vector2.ZERO])
		var angle := facing.angle()
		for i in 9:
			points.append(Vector2.from_angle(angle - SIGHT_ANGLE + SIGHT_ANGLE * 2.0 * i / 8.0) * reach)
		draw_colored_polygon(points, CHASE_COLOR if mode == Mode.CHASE else CONE_COLOR)
	Fx.draw_shadow(self, half - 2.0, 24.0)
	if alert > 0.0:  # "!" qui surgit
		var pop := 1.0 + 0.4 * (alert / 0.6)
		draw_set_transform(Vector2(0, -half - 18.0), 0.0, Vector2(pop, pop))
		draw_rect(Rect2(-4, -9, 8, 18), Color(0.1, 0.06, 0.12, 0.85))
		draw_rect(Rect2(-2, -7, 4, 8), Color(1, 0.4, 0.35))
		draw_rect(Rect2(-2, 3, 4, 4), Color(1, 0.4, 0.35))
		draw_set_transform(Vector2.ZERO)
	elif mode == Mode.SLEEP:
		var z := Vector2(10, -half - 10.0 - fmod(bob * 8.0, 10.0))
		draw_string(ThemeDB.get_project_theme().default_font, z, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.85, 1, 0.8))
