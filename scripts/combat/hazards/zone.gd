extends Node2D

# Zone au sol. Pale pendant arm_delay (telegraphe), puis active pendant active_time :
#   "damage" : blesse le joueur qui s'y trouve (son invincibilite apres un coup evite l'acharnement) ;
#   "slow"   : ralentit le joueur tant qu'il est dedans ;
#   "push"   : pousse le joueur dans la direction push (tapis roulant...) ;
#   "mark"   : simple trace visuelle, sans effet (traces de pas...).
# Voir Hazards.zone().

var radius := 60.0
var kind := "damage"
var arm_delay := 0.8
var active_time := 0.2
var color := Color(1, 0.4, 0.4)
var push := Vector2.ZERO
var damage := 1
var t := 0.0
var art_seed := randf() * 100.0  # pour que deux zones voisines n'ondulent pas pareil

func _physics_process(delta: float) -> void:
	t += delta
	if t > arm_delay + active_time:
		queue_free()
		return
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p and t >= arm_delay and p.global_position.distance_to(global_position) <= radius + 8.0:
		match kind:
			"damage":
				p.take_damage(damage)
			"slow":
				p.apply_slow(0.2, 0.45)
			"push":
				p.add_external_velocity(push)
	queue_redraw()

func _draw() -> void:
	match kind:
		"slow":
			_draw_puddle()
		"push":
			_draw_push()
		_:
			_draw_damage()

# Zone de degats. Annonce : un cercle en pointilles qui tourne et un disque qui se remplit jusqu'a
# la frappe. Frappe breve : un eclat. Frappe longue : une braise qui couve.
func _draw_damage() -> void:
	var dark := HazardArt.outline(color)
	if t < arm_delay:
		var p := t / maxf(arm_delay, 0.01)
		var urgent := p > 0.75 and int(t * 16.0) % 2 == 0
		draw_circle(Vector2.ZERO, radius, Color(color, 0.1))
		draw_circle(Vector2.ZERO, radius * p, Color(color, 0.2 + 0.14 * p))
		draw_arc(Vector2.ZERO, radius + 1.5, 0.0, TAU, 40, Color(dark, 0.5), 1.5)
		HazardArt.dashed_circle(self, radius, HazardArt.light(color) if urgent else Color(color, 0.95), 2.5, maxi(8, int(radius / 5.0)), t * 1.6)
		return
	var q := clampf((t - arm_delay) / maxf(active_time, 0.01), 0.0, 1.0)
	if active_time <= 0.4:  # eclat
		var flash := 1.0 - q
		draw_circle(Vector2.ZERO, radius, Color(color, 0.5 + 0.35 * flash))
		draw_circle(Vector2.ZERO, radius * 0.62, Color(HazardArt.light(color), 0.75 * flash))
		for i in 10:
			var a := TAU * i / 10.0 + art_seed
			draw_line(Vector2.from_angle(a) * radius * (0.45 + 0.3 * q), Vector2.from_angle(a) * radius * (1.0 + 0.3 * q), Color(HazardArt.light(color), 0.9 * flash), 3.0)
		draw_arc(Vector2.ZERO, radius * (1.0 + 0.25 * q), 0.0, TAU, 40, Color(1, 1, 1, 0.85 * flash), 3.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, dark, 2.0)
		return
	# Braise : reste dangereuse tant qu'elle couve, s'eteint a la fin.
	var fade := clampf((arm_delay + active_time - t) / 0.3, 0.0, 1.0)
	HazardArt.blob(self, radius + 2.0, Color(dark, 0.55 * fade), t, 0.05, art_seed)
	HazardArt.blob(self, radius, Color(color, 0.55 * fade), t, 0.05, art_seed)
	HazardArt.blob(self, radius * 0.62, Color(HazardArt.light(color), 0.4 * fade), t * 1.4, 0.1, art_seed + 3.0)
	for i in 5:
		var life := fmod(t * 0.9 + i * 0.37 + art_seed, 1.0)
		var at := Vector2.from_angle(i * 2.4 + art_seed) * radius * (0.25 + 0.45 * fmod(i * 0.61 + art_seed, 1.0))
		draw_circle(at + Vector2(0, -life * 8.0), 2.0 + 2.0 * life, Color(1, 1, 1, 0.6 * (1.0 - life) * fade))

# Flaque qui ralentit (brouillard, cire) : une tache molle ou tournent des volutes.
func _draw_puddle() -> void:
	var fade := clampf(t / maxf(arm_delay, 0.15), 0.0, 1.0) * clampf((arm_delay + active_time - t) / 0.4, 0.0, 1.0)
	HazardArt.blob(self, radius, Color(color, 0.3 * fade), t, 0.07, art_seed)
	HazardArt.blob(self, radius * 0.7, Color(HazardArt.light(color), 0.2 * fade), t * 1.3, 0.1, art_seed + 2.0)
	for i in 3:
		var a := t * (0.8 + 0.2 * i) + i * TAU / 3.0 + art_seed
		draw_arc(Vector2.ZERO, radius * (0.35 + 0.18 * i), a, a + 1.6, 10, Color(HazardArt.light(color), 0.4 * fade), 2.0)

# Zone qui pousse : des chevrons qui defilent dans le sens de la poussee.
func _draw_push() -> void:
	var fade := clampf(t / maxf(arm_delay, 0.15), 0.0, 1.0) * clampf((arm_delay + active_time - t) / 0.3, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.14 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.5 * fade), 2.0)
	var dir := push.normalized() if push != Vector2.ZERO else Vector2.RIGHT
	var side := dir.orthogonal()
	var spacing := radius * 0.55
	for i in 4:
		var along := fmod(t * 70.0 + i * spacing, spacing * 4.0) - spacing * 2.0
		var alpha := (1.0 - absf(along) / (spacing * 2.0)) * fade
		var tip := dir * (along + 8.0)
		draw_polyline(PackedVector2Array([dir * along + side * 12.0, tip, dir * along - side * 12.0]), Color(HazardArt.light(color), 0.8 * alpha), 3.0)
