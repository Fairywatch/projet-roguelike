extends BaseMob

# Carrefour (mercredi, Doute) : tire deux salves vers deux chemins, l'une reelle et l'autre
# fausse (inoffensive). Seul indice : la fausse salve est un peu plus transparente.
# Variante : se teleporte entre 3 positions dont 2 leurres (on ne frappe que le vrai).
# Cauchemar : salves plus fournies.

const REAL := Color(1, 0.8, 0.5, 0.95)
const FAKE := Color(1, 0.8, 0.5, 0.55)
const SPREAD := 0.6  # ecart entre les deux chemins (radians)

var decoys: Array = []

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mercredi/carrefour.png"

func _on_ready() -> void:
	display_name = "Carrefour"
	hp = 4
	chase_speed = 35.0
	attack_range = 280.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.5
	if alt:
		for i in 2:
			var decoy := Sprite2D.new()
			decoy.texture = sprite.texture
			decoy.hframes = ANIM_FRAMES
			decoy.scale = sprite.scale
			decoy.position = Hazards.clamp_to_arena(position + Vector2.from_angle(TAU * (i + 1) / 3.0) * 180.0)
			decoys.append(decoy)
			get_parent().add_child.call_deferred(decoy)

func _on_attack_begin() -> void:
	var aim := (player.global_position - global_position).angle()
	var real_first := randf() < 0.5
	var count := 4 if nightmare else 3
	for k in 2:
		var path := aim + (SPREAD if k == 0 else -SPREAD) * 0.5
		var real := (k == 0) == real_first
		for i in count:
			var shot := Hazards.shoot(self, Vector2.from_angle(path + (i - (count - 1) / 2.0) * 0.12), 160.0, REAL if real else FAKE)
			shot.harmless = not real

func _on_attack_end() -> void:
	if not alt:
		return
	# Les trois positions sont rebattues : le vrai Carrefour peut etre n'importe lequel.
	var spots := []
	for i in 3:
		spots.append(Hazards.clamp_to_arena(player.global_position + Vector2.from_angle(TAU * i / 3.0 + randf()) * 200.0))
	spots.shuffle()
	global_position = spots[0]
	for i in decoys.size():
		if is_instance_valid(decoys[i]):
			decoys[i].global_position = spots[i + 1]

func _on_death() -> void:
	for decoy in decoys:
		if is_instance_valid(decoy):
			decoy.queue_free()
