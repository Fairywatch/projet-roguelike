# Lancer : godot --headless --path . --script res://tests/test_styles.gd
# Objets qui changent la facon de jouer : styles d'attaque (estoc, toupie, fronde, maillet), dash
# qui blesse (Pantoufles-fusees) et Moutons gardiens.
extends SceneTree

var gs
var bestiary

func _arena() -> Node:
	gs.new_run(0)
	gs.floor_index = 1
	gs.guardian_fight = false
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	for m in get_nodes_in_group("mobs"):
		m.free()
	current_scene.combat_over = true  # le test pilote les ennemis lui-meme
	current_scene.player.invincible = true
	current_scene.player.global_position = Vector2(450, 270)
	return current_scene

# Mouton d'entrainement immobile, plein de PV, a `offset` du joueur.
func _dummy(a: Node, offset: Vector2) -> Node:
	var mob = bestiary.make("lundi/mouton")
	a._spawn_mob(mob)
	mob.set_physics_process(false)
	mob.hp = 99
	mob.max_hp = 99
	mob.global_position = a.player.global_position + offset
	return mob

func _clear() -> void:
	for m in get_nodes_in_group("mobs"):
		m.free()
	await physics_frame

func _take(a: Node, id: String) -> void:
	gs.take_item(id)
	a.player.apply_items()

# Un coup simple (pas d'enchainement ni de coup plongeant), dans la direction donnee.
func _swing(a: Node, direction: Vector2, frames: int = 6) -> void:
	var p = a.player
	p.facing = direction
	p.attack_cooldown_timer = 0.0
	p.combo_timer = 0.0
	p.dash_strike_timer = 99.0
	p._try_attack()
	for i in frames:
		await physics_frame

func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.upgrades = {}
	gs.week = 1
	gs.start_bag.clear()
	bestiary = load("res://scripts/combat/bestiary.gd")
	var stats = load("res://scripts/combat/player_stats.gd")  # charge a l'execution : il lit GameState

	var a = await _arena()
	# Coup de base : un ennemi a 100 px n'est pas touche, ni un ennemi dans le dos.
	var far = _dummy(a, Vector2(100, 0))
	var behind = _dummy(a, Vector2(-40, 0))
	await _swing(a, Vector2.RIGHT)
	assert(far.hp == 99 and behind.hp == 99)

	# Estoc (Aiguille a tricoter) : deux fois plus loin, a travers toute la ligne.
	_take(a, "aiguille_a_tricoter")
	assert(stats.style() == "estoc")
	var near = _dummy(a, Vector2(45, 0))
	await _swing(a, Vector2.RIGHT)
	assert(far.hp == 98 and near.hp == 98 and behind.hp == 99)
	assert(stats.attack_cooldown() > stats.ATTACK_COOLDOWN)
	await _clear()

	# Le dernier style pris est le style actif (un seul a la fois) ; sa lenteur seule compte.
	_take(a, "toupie")
	assert(stats.style() == "toupie" and is_equal_approx(stats.attack_cooldown(), stats.ATTACK_COOLDOWN * stats.STYLES["toupie"]["cooldown"]))
	# Toupie : tout autour du joueur, dans le dos aussi.
	var back = _dummy(a, Vector2(-40, 0))
	var side = _dummy(a, Vector2(0, 40))
	await _swing(a, Vector2.RIGHT)
	assert(back.hp == 98 and side.hp == 98)
	await _clear()

	# Fronde (Lance-pierre) : un oreiller touche de loin ; pas de coup au corps a corps.
	_take(a, "lance_pierre")
	var target = _dummy(a, Vector2(220, 0))
	await _swing(a, Vector2.RIGHT, 40)
	assert(target.hp == 98)
	await _clear()

	# Maillet : un coup lourd (double degats) qui assomme un ennemi ordinaire.
	_take(a, "maillet_de_morphee")
	var struck = _dummy(a, Vector2(40, 0))
	struck.set_physics_process(true)
	await _swing(a, Vector2.RIGHT, 3)
	assert(struck.hp == 97 and struck.state == struck.State.COOLDOWN and a.player.combo == 0)
	await _clear()
	assert(stats.lines().any(func(line): return line[0] == "Style" and line[1] == "Maillet"))

	# Pantoufles-fusees : le dash blesse l'ennemi touche (une fois) et se recharge aussitot.
	gs.new_run(0)
	a = await _arena()
	_take(a, "pantoufles_fusees")
	var crossed = _dummy(a, Vector2(50, 0))
	a.player.facing = Vector2.RIGHT
	a.player._start_dash()
	for i in 20:
		await physics_frame
	assert(crossed.hp == 98)
	assert(a.player.dash_cooldown_timer <= a.player.dash_cooldown_effective * a.player.DASH_HIT_REFUND)
	await _clear()

	# Moutons gardiens : deux moutons qui tournent ; l'un arrete un tir ennemi puis est etourdi.
	_take(a, "moutons_gardiens")
	var flock: Array = a.player.get_children().filter(func(n): return n.is_in_group("guard_sheep"))
	assert(flock.size() == 2)
	for i in 3:
		await physics_frame
	var shooter = _dummy(a, Vector2(200, 0))
	var shot: Node = load("res://scripts/combat/hazards.gd").shoot(shooter, Vector2.LEFT, 0.0)
	shot.global_position = flock[0].global_position
	for i in 4:
		await physics_frame
	assert(not is_instance_valid(shot) or shot.is_queued_for_deletion())
	assert(flock.any(func(sheep): return sheep.dizzy > 0.0))
	# Un mouton mord un ennemi qu'il touche.
	var bitten = _dummy(a, Vector2.ZERO)
	bitten.global_position = flock[1].global_position
	for i in 4:
		await physics_frame
	assert(bitten.hp < 99 or flock[1].dizzy > 0.0)
	await _clear()

	print("test_styles OK")
	quit()
