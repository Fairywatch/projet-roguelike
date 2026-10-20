extends BaseMob

# Le Miroir Brise (boss du mercredi) : se divise en eclats qui le refletent tous ; tous tirent,
# mais seuls les tirs du vrai miroir blessent, et seul le vrai prend des degats. Toutes les deux
# attaques, les reflets changent de place. Variante : les eclats tirent en couronne.
# Cauchemar : un reflet de plus.

const SHARD := Color(0.75, 0.88, 1, 0.95)
const SHARD_FAKE := Color(0.75, 0.88, 1, 0.6)

var reflections: Array = []
var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mercredi/miroir_brise.png"

func _on_ready() -> void:
	display_name = "Le Miroir Brisé"
	is_boss = true
	hp = 18
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.3
	for i in 3 if nightmare else 2:
		var copy := Sprite2D.new()
		copy.texture = sprite.texture
		copy.hframes = ANIM_FRAMES
		copy.frame = 1
		copy.scale = sprite.scale
		reflections.append(copy)
		get_parent().add_child.call_deferred(copy)
	sprite.frame = 1
	auto_frames = false
	_shuffle.call_deferred()

func _shuffle() -> void:
	var spots := [Vector2(220, 150), Vector2(680, 150), Vector2(450, 400), Vector2(220, 400), Vector2(680, 400)]
	spots.shuffle()
	global_position = spots[0]
	for i in reflections.size():
		if is_instance_valid(reflections[i]):
			reflections[i].global_position = spots[i + 1]

func _on_attack_begin() -> void:
	cycle += 1
	var sources: Array = [self] + reflections.filter(func(r): return is_instance_valid(r))
	for source in sources:
		var real: bool = source == self
		var color := SHARD if real else SHARD_FAKE
		var shots: Array = []
		if alt:
			for i in 8:
				shots.append(_shard(source, Vector2.from_angle(TAU * i / 8.0 + cycle * 0.3), color))
		else:
			var aim: Vector2 = player.global_position - source.global_position
			for i in 3:
				shots.append(_shard(source, aim.rotated((i - 1) * 0.2), color))
		for shot in shots:
			shot.harmless = not real
	if cycle % 2 == 0:
		_shuffle()

# Les reflets ne sont pas des Node2D de combat : le tir part de leur position.
func _shard(source: Node2D, direction: Vector2, color: Color) -> Area2D:
	var shot := Hazards.shoot(self, direction, 150.0, color)
	shot.global_position = source.global_position + direction.normalized() * 22.0
	return shot

func _on_death() -> void:
	for copy in reflections:
		if is_instance_valid(copy):
			Fx.puff(copy.get_parent(), copy.global_position, SHARD, 12)
			copy.queue_free()
