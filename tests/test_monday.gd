# Lancer : godot --headless --path . --script res://tests/test_monday.gd
# Bestiaire du lundi (docs/bestiaire.md) : chaque creature et chaque boss se bat sans erreur,
# et leurs mecaniques propres fonctionnent.
extends SceneTree

const CREATURES := ["lundi/bailleur", "lundi/mouton", "lundi/veilleuse", "lundi/paupiere"]
const BOSSES := ["lundi/grande_couette", "lundi/reveil_grincheux", "lundi/choeur_baillements", "lundi/porte_des_voix"]

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
	current_scene.combat_over = true  # on pilote les ennemis nous-memes
	current_scene.player.invincible = true
	return current_scene

func _spawn(arena: Node, path: String, flags: Dictionary = {}) -> Node:
	var mob = bestiary.make(path)
	for key in flags:
		mob.set(key, flags[key])
	arena._spawn_mob(mob)
	mob.global_position = arena.player.global_position + Vector2(140, 0)
	return mob

func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	bestiary = load("res://scripts/combat/bestiary.gd")

	# Un combat normal du lundi tire ses ennemis dans le bestiaire du lundi.
	gs.new_run(0)
	gs.floor_index = 1
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	var names := ["Bailleur", "Mouton insomniaque", "Veilleuse fatiguee", "Paupiere lourde"]
	for m in get_nodes_in_group("mobs"):
		assert(m.display_name in names)

	# Chaque creature et chaque boss (et ses variantes) attaque plusieurs fois sans erreur.
	var arena = await _arena()
	for path in CREATURES + BOSSES:
		for flags in [{}, {"alt": true}, {"nightmare": true, "elite": true}]:
			var mob = _spawn(arena, path, flags)
			await create_timer(3.0).timeout
			assert(is_instance_valid(mob) and mob.state != mob.State.DEAD)
			for m in get_nodes_in_group("mobs"):
				m.queue_free()
			await process_frame

	# Paupiere fermee : invulnerable ; ouverte (telegraphe) : vulnerable.
	var eye = _spawn(arena, "lundi/paupiere")
	await process_frame
	var hp: int = eye.hp
	eye.take_hit(1)
	assert(eye.hp == hp and eye.invulnerable)
	eye._start_telegraph()
	eye.take_hit(1)
	assert(eye.hp == hp - 1)
	eye.queue_free()

	# Reveil en "snooze" : double degats.
	var clock = _spawn(arena, "lundi/reveil_grincheux")
	await process_frame
	clock._snooze()
	hp = clock.hp
	clock.take_hit(1)
	assert(clock.hp == hp - 2)
	clock.queue_free()

	# Bailleur qui aspire : le joueur est attire vers lui.
	var yawner = _spawn(arena, "lundi/bailleur")
	await process_frame
	yawner.state = yawner.State.ATTACK
	await physics_frame
	await physics_frame
	assert(arena.player.external_velocity != Vector2.ZERO or arena.player.velocity.dot(yawner.global_position - arena.player.global_position) > 0.0)
	yawner.queue_free()

	# Porte des Voix : phase 2 sous 66 % de PV, invulnerable hors des grincements.
	var door = _spawn(arena, "lundi/porte_des_voix")
	await process_frame
	door.take_hit(int(door.max_hp * 0.4))
	assert(door.phase == 2 and door.invulnerable)
	hp = door.hp
	door.take_hit(1)
	assert(door.hp == hp)
	await create_timer(door.CREAK_EVERY + door.CREAK_WARNING + 0.3).timeout
	assert(not door.invulnerable)
	door.take_hit(int(door.max_hp * 0.4))
	assert(door.phase == 3)
	door.queue_free()

	# Boss de portail : 12 combinaisons differentes avant toute repetition.
	var history := []
	var seen := {}
	for i in 12:
		var boss = bestiary.boss("lundi", false, history)
		var key: String = history.back()
		assert(not seen.has(key))
		seen[key] = true
		boss.free()
	assert(seen.size() == 12)

	# Dernier portail du lundi : la Porte des Voix.
	gs.new_run(0)
	gs.floor_index = gs.floor_count() - 1
	gs.start_guardian_fight(false)
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	var final_boss = get_nodes_in_group("mobs")[0]
	assert(final_boss.display_name == "La Porte des Voix" and current_scene.is_boss_fight)
	gs.guardian_fight = false

	print("test_monday OK")
	quit()
