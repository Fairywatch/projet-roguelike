# Banc d'equilibrage : un bot joue les vrais combats de chaque nuit (vraie arene, vrais mobs,
# vraie difficulte), en accelere et sans fenetre, et note les PV perdus et la duree.
# Le bot esquive en prevoyant les dangers (projectiles, zones, rayons, anneaux, balayages...)
# et frappe l'ennemi le plus proche : il joue moins bien qu'un humain attentif, mais pareil d'une
# nuit a l'autre. Ce sont donc les ecarts entre nuits, etages et mobs qui comptent.
#
#   godot --headless --path . -s res://tools/balance/combat_sim.gd -- <nuit> [essais] [kit]
#     nuit : 0 (lundi) a 6 (dimanche) ; kit : none (aucun objet), loot (objets d'une run moyenne)
#     ou final (seulement le boss de fin, en alternant Normal et Cauchemar, pour un diagnostic)
# Chaque combat ecrit une ligne "SIM {json}" ; tools/balance/report.py en fait un tableau.
extends SceneTree

const ARENA_SCENE := "res://scenes/combat/CombatArena.tscn"
const TIMEOUT := 150.0  # secondes de jeu avant d'abandonner un combat
const STEP := 0.05
const HORIZON := 0.3  # le bot prevoit les dangers sur 0,3 s
const SPEED := 8
const PLAYER_HP := 999  # le bot ne meurt pas : on compte les PV qu'il aurait perdus
const ITEMS_PER_FLOOR := 3.0  # kit "loot" : butin moyen ramasse par etage (combats, coffres, quetes)

var gs: Node
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://sim_run.save"
	gs.meta_path = "user://sim_meta.save"
	# Jeu accelere : SPEED fois plus d'images de physique par seconde, chacune du meme pas de temps.
	Engine.max_fps = 0
	Engine.time_scale = SPEED
	Engine.physics_ticks_per_second = 60 * SPEED
	Engine.max_physics_steps_per_frame = 8 * SPEED
	Settings.values["hitstop"] = false
	Settings.values["screen_shake"] = false
	var args := OS.get_cmdline_user_args()
	var night := int(args[0]) if args.size() > 0 else 0
	var trials := int(args[1]) if args.size() > 1 else 8
	var kit := args[2] if args.size() > 2 else "none"
	rng.seed = 1000 + night
	var floors: int = Towers.LIST[night]["floors"]
	var sampled_floors := [0, floors / 2, floors - 1]
	if kit == "final":
		for i in trials:
			await fight(night, floors - 1, "final", i % 2 == 1, "none")
		quit()
		return
	for nightmare in [false, true]:
		for floor_index in sampled_floors:
			for i in trials:
				await fight(night, floor_index, "creatures", nightmare, kit)
			for i in maxi(2, trials / 2):
				await fight(night, floor_index, "guardian", nightmare, kit)
		for i in maxi(2, trials / 2):
			await fight(night, floors - 1, "final", nightmare, kit)
	quit()


# Objets d'une run moyenne arrivee a cet etage : tires comme en jeu, qualite comprise.
func give_loot(floor_index: int) -> void:
	var count := int(round((floor_index + 1) * ITEMS_PER_FLOOR * 0.5))  # la moitie seulement est gardee (choix, morts)
	for i in count:
		var id: String = gs.roll_item_id()
		if Items.is_active(id):
			continue
		gs.add_passive_item(id)


func fight(night: int, floor_index: int, kind: String, nightmare: bool, kit: String) -> void:
	gs.new_run(night, false, nightmare)
	gs.floor_index = floor_index
	var family := rng.randi() % 2
	var floor_data: Dictionary = gs.get_or_create_floor_data(floor_index)
	floor_data["family"] = family
	gs.guardian_fight = kind != "creatures"
	gs.guardian_exit_down = false
	if kit == "loot":
		give_loot(floor_index)
	var started := Time.get_ticks_msec()
	change_scene_to_file(ARENA_SCENE)
	for i in 6:
		await process_frame
	var arena := current_scene
	arena.set_process(false)  # le banc juge lui-meme la victoire : pas de butin ni de retour a la carte
	var player = arena.player
	player.max_hp = PLAYER_HP
	player.hp = PLAYER_HP
	var mobs := get_nodes_in_group("mobs").map(func(m): return m.get_script().resource_path.get_file().get_basename())
	var bot := Bot.new()
	bot.player = player
	bot.arena = arena
	arena.add_child(bot)
	var time := 0.0
	var won := false
	while time < TIMEOUT:
		await physics_frame
		time += Engine.time_scale / Engine.physics_ticks_per_second
		if bot.alive_mobs().is_empty():
			won = true
			break
	arena.combat_over = true
	gs.end_combat()
	var result := {
		"night": night, "floor": floor_index, "kind": kind, "nightmare_mode": nightmare, "kit": kit,
		"family": family, "intensity": floor_data["intensity"], "difficulty": snappedf(gs.difficulty(), 0.01),
		"mobs": mobs, "hp_lost": PLAYER_HP - player.hp, "time": snappedf(time, 0.1), "won": won,
		"items": gs.passive_count(), "real_ms": Time.get_ticks_msec() - started,
		"left": bot.alive_mobs().map(func(m): return "%s(%d%s%s)" % [m.display_name, m.hp, " inv" if m.invulnerable else "", " " + str(Vector2i(m.global_position))]),
	}
	print("SIM ", JSON.stringify(result))


class Bot extends Node:
	var player: CharacterBody2D
	var arena: Node
	const DIRECTIONS := 16
	# Dangers du moment, relus une fois par image (et non a chaque point teste).
	var hazards: Array = []
	var mobs: Array = []

	func _ready() -> void:
		process_physics_priority = -100  # decide avant que le joueur ne lise ses touches

	func alive_mobs() -> Array:
		return get_tree().get_nodes_in_group("mobs").filter(func(m): return is_instance_valid(m) and m.state != BaseMob.State.DEAD)

	# Demi-taille de la zone de frappe d'un mob (les gros boss se touchent de plus loin).
	static func body_radius(m: Node) -> float:
		var shape := m.get_node_or_null("Hurtbox/CollisionShape2D")
		if shape and shape.shape is RectangleShape2D:
			return maxf(shape.shape.size.x, shape.shape.size.y) / 2.0
		return 16.0

	# Cible : l'ennemi le plus proche, mais le boss passe avant ses sbires (sauf s'ils collent).
	func _target() -> Node2D:
		var best: Node2D = null
		var best_d := INF
		var boss_here := mobs.any(func(m): return m.is_boss and not m.invulnerable)
		for m in mobs:
			var d: float = player.global_position.distance_to(m.global_position) + (400.0 if m.invulnerable else 0.0)
			if boss_here and not m.is_boss and d > 60.0:
				d += 250.0
			if d < best_d:
				best_d = d
				best = m
		return best

	func _refresh() -> void:
		mobs = alive_mobs()
		hazards.clear()
		for node in get_tree().current_scene.get_children():
			var script: Script = node.get_script()
			if script == null:
				continue
			var kind := script.resource_path.get_file().get_basename()
			if kind in ["projectile", "zone", "beam", "ring_wave", "sweep", "boulder", "shrink"]:
				if kind == "projectile" and node.harmless:
					continue
				if kind == "zone" and node.kind != "damage":
					continue
				hazards.append([kind, node])

	func _physics_process(_delta: float) -> void:
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		if player.dead:
			return
		_refresh()
		var here: Vector2 = player.global_position
		var target := _target()
		var strike: float = player.reach + (body_radius(target) if target else 0.0) + 14.0
		var speed: float = player.move_speed
		var best_dir := Vector2.ZERO
		var best_cost := INF
		var best_danger := INF
		for i in DIRECTIONS + 1:
			var dir := Vector2.ZERO if i == DIRECTIONS else Vector2.from_angle(TAU * i / DIRECTIONS)
			var end := here + dir * speed * HORIZON
			var danger := danger_along(here, end, HORIZON)
			var cost := danger * 100.0 + _position_cost(end, target, strike - 10.0)
			if cost < best_cost:
				best_cost = cost
				best_dir = dir
				best_danger = danger
		var dash_reach: float = 600.0 * player.dash_duration
		var can_dash: bool = player.dash_cooldown_timer <= 0.0 and not player.dashing
		# Danger inevitable a pied : on dashe (invincible) vers l'endroit le plus sur.
		if best_danger >= 10.0 and can_dash:
			var dash_best := Vector2.ZERO
			var dash_cost := INF
			for i in DIRECTIONS:
				var dir := Vector2.from_angle(TAU * i / DIRECTIONS)
				var land := (here + dir * dash_reach).clamp(Hazards.ARENA.position, Hazards.ARENA.end)
				var cost := danger_along(land, land, HORIZON) * 100.0 + _position_cost(land, target, strike - 10.0)
				if cost < dash_cost:
					dash_cost = cost
					dash_best = dir
			player.facing = dash_best
			best_dir = dash_best
			player._start_dash()
		# Ouverture : le dash rend invincible, on s'en sert pour traverser les dangers jusqu'a la cible.
		elif target and not target.invulnerable and can_dash:
			var gap: Vector2 = target.global_position - here
			if gap.length() > strike and gap.length() < dash_reach + strike and danger_along(here, target.global_position, HORIZON) >= 3.0:
				player.facing = gap.normalized()
				best_dir = player.facing
				player._start_dash()
		if best_dir != Vector2.ZERO:
			if best_dir.x > 0: Input.action_press("move_right", best_dir.x)
			if best_dir.x < 0: Input.action_press("move_left", -best_dir.x)
			if best_dir.y > 0: Input.action_press("move_down", best_dir.y)
			if best_dir.y < 0: Input.action_press("move_up", -best_dir.y)
		# Un joueur attentif ne frappe pas la Colere pendant sa bourrasque (chaque coup la soigne).
		var punished: bool = target != null and target.get("gust") == true
		if target and target.get("FRONT_ARC") != null and (here - target.global_position).normalized().dot(target.facing) > target.FRONT_ARC:
			punished = true  # de face, le coup rebondit
		if target and not target.invulnerable and not punished and not player.dashing and player.attack_cooldown_timer <= 0.0:
			var to_target: Vector2 = target.global_position - here
			if to_target.length() <= strike:
				player.facing = to_target.normalized()
				player._try_attack()

	func _position_cost(at: Vector2, target: Node2D, wanted: float) -> float:
		var cost := 0.0
		if target:
			cost += absf(at.distance_to(target.global_position) - wanted) / 40.0
			if target.get("FRONT_ARC") != null and (at - target.global_position).normalized().dot(target.facing) > target.FRONT_ARC:
				cost += 1.5
		var arena_rect: Rect2 = Hazards.ARENA
		var edge := minf(minf(at.x - arena_rect.position.x, arena_rect.end.x - at.x), minf(at.y - arena_rect.position.y, arena_rect.end.y - at.y))
		if edge < 30.0:
			cost += (30.0 - edge) / 10.0
		return cost

	# Danger d'un trajet en ligne droite de `from` a `to` pendant `duration` secondes.
	func danger_along(from: Vector2, to: Vector2, duration: float) -> float:
		var total := 0.0
		var s := STEP
		while s <= duration + 0.001:
			total = maxf(total, danger_at(from.lerp(to, s / duration), s))
			if total >= 10.0:
				break
			s += STEP
		return total

	func danger_at(p: Vector2, s: float) -> float:
		var danger := 0.0
		for entry in hazards:
			var node = entry[1]
			if not is_instance_valid(node):
				continue
			match entry[0]:
				"projectile":
					var q: Vector2 = node.global_position + node.direction * node.speed * s
					if p.distance_to(q) < 30.0:
						return 10.0
				"zone":
					if p.distance_to(node.global_position) <= node.radius + 18.0:
						var tt: float = node.t + s
						if tt >= node.arm_delay - 0.05 and tt <= node.arm_delay + node.active_time:
							return 10.0
						danger = maxf(danger, 3.0)
				"beam":
					if not node.hit and _in_beam(p, node.global_position, node.direction.angle(), node.LENGTH, node.width / 2.0 + 18.0):
						if node.t + s >= node.telegraph - 0.05:
							return 10.0
						danger = maxf(danger, 3.0)
				"ring_wave":
					if not node.hit:
						var r: float = node.radius + node.speed * s
						var offset: Vector2 = p - node.global_position
						if absf(offset.length() - r) < node.THICKNESS / 2.0 + 16.0 and not node.in_gap(offset.angle()):
							return 10.0
				"sweep":
					var tt: float = node.t + s
					if tt >= node.telegraph:
						var active_t: float = tt - node.telegraph
						var angle: float = node.start_angle + (sin(active_t * node.angular_speed) * node.swing if node.swing > 0.0 else active_t * node.angular_speed)
						if _in_beam(p, node.global_position, angle, node.length, node.width / 2.0 + 18.0):
							return 10.0
				"boulder":
					var q: Vector2 = node.global_position + node.direction * node.speed * s
					if p.distance_to(q) < node.radius + 22.0:
						return 10.0
				"shrink":
					if not node.retracting and node.t + s >= node.telegraph:
						var half: Vector2 = (node.rect.size / 2.0 - Vector2.ONE * node.speed * s).max(node.MIN_HALF_SIZE)
						if not Rect2(node.ARENA.get_center() - half, half * 2.0).grow(-6.0).has_point(p):
							return 10.0
		for m in mobs:
			if not is_instance_valid(m):
				continue
			if m.get("move_dir") != null and m.state == BaseMob.State.CHASE:
				var q: Vector2 = m.global_position + m.move_dir * m.speed * s
				if p.distance_to(q) < 40.0:
					return 10.0
			var d: float = p.distance_to(m.global_position) - body_radius(m)
			if m.state == BaseMob.State.ATTACK and d < 50.0:
				danger = maxf(danger, 6.0)
			elif m.state == BaseMob.State.TELEGRAPH and m.attack_range < 300.0 and d < 70.0:
				danger = maxf(danger, 4.0)
			elif d < 10.0:
				danger = maxf(danger, 2.0)
		return danger

	func _in_beam(p: Vector2, origin: Vector2, angle: float, length: float, half_width: float) -> bool:
		var local := (p - origin).rotated(-angle)
		return local.x >= -10.0 and local.x <= length and absf(local.y) <= half_width
