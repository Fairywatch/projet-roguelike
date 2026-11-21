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
var art: ShaderMaterial

func _ready() -> void:
	z_index = -1  # au sol : sous les ennemis, le joueur et les projectiles (le fond est a -10)
	art = PixelFx.material(PixelFx.ZONE, color)
	art.set_shader_parameter("radius", radius)
	art.set_shader_parameter("seed", art_seed)
	art.set_shader_parameter("push_dir", push.normalized() if push != Vector2.ZERO else Vector2.RIGHT)
	material = art

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
	# Pixel art (assets/shaders/pixel_zone.gdshader) : annonce, frappe breve, zone qui couve,
	# brume qui ralentit, zone qui pousse ; motif de la nuit en cours.
	var mode := 0
	var progress := 0.0
	match kind:
		"slow":
			mode = 3
			progress = clampf(t / maxf(arm_delay, 0.15), 0.0, 1.0) * clampf((arm_delay + active_time - t) / 0.4, 0.0, 1.0)
		"push":
			mode = 4
			progress = clampf(t / maxf(arm_delay, 0.15), 0.0, 1.0) * clampf((arm_delay + active_time - t) / 0.3, 0.0, 1.0)
		_:
			if t < arm_delay:
				progress = t / maxf(arm_delay, 0.01)
			elif active_time <= 0.4:  # eclat
				mode = 1
				progress = clampf((t - arm_delay) / maxf(active_time, 0.01), 0.0, 1.0)
			else:  # couve, puis s'eteint
				mode = 2
				progress = clampf((arm_delay + active_time - t) / 0.3, 0.0, 1.0)
	art.set_shader_parameter("mode", mode)
	art.set_shader_parameter("progress", progress)
	art.set_shader_parameter("time", t)
	var reach := radius * 1.35 + 8.0
	draw_rect(Rect2(-reach, -reach, reach * 2.0, reach * 2.0), Color.WHITE)
