# Verification commune du bestiaire d'une nuit (docs/bestiaire.md), reprise par test_<nuit>.gd :
#   - un combat ordinaire de la nuit tire ses ennemis dans son bestiaire ;
#   - chaque creature, chaque boss et le boss de fin se battent dans chaque variante ;
#   - 12 boss de portail differents avant toute repetition ;
#   - le dernier portail de la nuit est garde par son boss de fin.
# Les erreurs de script apparaissent dans la sortie ("SCRIPT ERROR") : lancer avec un timeout.
extends SceneTree

const FIGHT_TIME := 2.0
const VARIANTS := [{}, {"alt": true}, {"nightmare": true, "elite": true}]

var night := ""
var gs
var bestiary

# Surcharge par chaque test de nuit : verifications propres a ses creatures.
func check_specific(_arena: Node) -> void:
	pass

func night_index() -> int:
	for i in Towers.LIST.size():
		if Towers.LIST[i]["id"] == night:
			return i
	return -1

func arena() -> Node:
	gs.new_run(night_index())
	gs.floor_index = 1
	gs.guardian_fight = false
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	for m in get_nodes_in_group("mobs"):
		m.free()
	current_scene.combat_over = true  # le test pilote les ennemis lui-meme
	current_scene.player.invincible = true
	return current_scene

func spawn(arena_node: Node, path: String, flags: Dictionary = {}) -> Node:
	var mob = bestiary.make(path)
	for key in flags:
		mob.set(key, flags[key])
	arena_node._spawn_mob(mob)
	mob.global_position = arena_node.player.global_position + Vector2(150, 0)
	return mob

func clear_mobs() -> void:
	for m in get_nodes_in_group("mobs"):
		m.queue_free()
	await process_frame

func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	bestiary = load("res://scripts/combat/bestiary.gd")
	var data: Dictionary = bestiary.NIGHTS[night]

	var creature_scripts: Array = data["creatures"].map(func(path): return bestiary.MOBS_DIR + path + ".gd")
	gs.new_run(night_index())
	gs.floor_index = 1
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	for m in get_nodes_in_group("mobs"):
		assert(m.get_script().resource_path in creature_scripts)

	var a = await arena()
	for path in data["creatures"] + data["bosses"] + [data["final"]]:
		for flags in VARIANTS:
			var mob = spawn(a, path, flags)
			await create_timer(FIGHT_TIME).timeout
			assert(is_instance_valid(mob))
			await clear_mobs()

	var history := []
	var seen := {}
	for i in 12:
		var boss = bestiary.boss(night, i % 2 == 0, history)
		assert(not seen.has(history.back()))
		seen[history.back()] = true
		boss.free()

	a = await arena()
	await check_specific(a)
	await clear_mobs()

	gs.new_run(night_index())
	gs.floor_index = gs.floor_count() - 1
	gs.start_guardian_fight(false)
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	var final_boss = get_nodes_in_group("mobs")[0]
	assert(final_boss.get_script().resource_path == bestiary.MOBS_DIR + data["final"] + ".gd" and current_scene.is_boss_fight)
	gs.guardian_fight = false

	print("test_%s OK" % night)
	quit()
