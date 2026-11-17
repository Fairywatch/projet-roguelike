# Lancer : godot --headless --path . --script res://tests/test_progression.gd
# Regles de progression : enchainement et coup plongeant, fuite payante, ameliorations permanentes,
# bilan de nuit, semaine suivante.
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.upgrades = {}
	gs.week = 1
	gs.start_bag.clear()
	gs.new_run(0)

	# Ameliorations permanentes : chaque niveau a son prix, puis "au maximum".
	gs.coins = 1000
	assert(gs.upgrade_price("coeur") == 40 and gs.buy_upgrade("coeur") and gs.coins == 960)
	assert(gs.max_hp() == gs.BASE_MAX_HP + 1)
	assert(gs.upgrade_price("coeur") == 90 and gs.buy_upgrade("coeur") and gs.upgrade_price("coeur") == -1)
	assert(not gs.buy_upgrade("coeur") and gs.max_hp() == gs.BASE_MAX_HP + 2)
	assert(gs.buy_upgrade("poches") and gs.kept_on_death() == gs.DEATH_KEPT_ITEMS + 1)
	gs.shop_offers.clear()
	assert(gs.buy_upgrade("marchande") and gs.get_shop_offers().size() == gs.SHOP_SIZE + 1)
	assert(gs.buy_upgrade("doudou"))
	gs.new_run(0)
	assert(gs.passive_count() == 1 and Items.find_passive(gs.passive_items.keys()[0])["rarity"] == Items.COMMUN)
	gs.coins = 0
	assert(not gs.buy_upgrade("poches"))
	gs.upgrades = {}

	# Bilan de nuit, et semaine suivante quand les sept nuits sont faites.
	gs.new_run(0)
	gs.note("wins", 3)
	gs.note("kills", 7)
	gs.take_item("plume_de_reve")
	gs.floor_index = gs.floor_count() - 1
	gs.complete_tower()
	assert(gs.menu_message.contains("Bilan : 3 combats gagnés, 7 ennemis vaincus, 1 objet, sans mourir"))
	assert(gs.week == 1)
	gs.completed_towers = Towers.LIST.slice(0, 6).map(func(tower): return tower["id"])
	gs.unlocked_towers = 7
	var last := Towers.LIST.size() - 1
	gs.new_run(last)
	gs.current_floor()["family"] = FloorGenerator.Family.PARADOXAL  # le sommeil profond ajoute 15 %
	var base_difficulty: float = gs.difficulty()
	gs.coins = 0
	gs.floor_index = gs.floor_count() - 1
	gs.complete_tower()
	assert(gs.week == 2 and gs.completed_towers.is_empty() and gs.coins == Towers.LIST[last]["reward"])
	assert(gs.menu_message.contains("Semaine 2"))
	gs.new_run(last)
	gs.current_floor()["family"] = FloorGenerator.Family.PARADOXAL
	assert(is_equal_approx(gs.difficulty(), base_difficulty + gs.WEEK_DIFFICULTY))
	assert(gs.tower_reward() == roundi(Towers.LIST[last]["reward"] * 1.5))
	gs.week = 1

	# Enchainement : le troisieme coup frappe deux fois plus fort ; coup plongeant apres un dash.
	gs.new_run(0)
	gs.floor_index = 1
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	var arena = current_scene
	var player = arena.player
	var kinds := []
	for i in 3:
		player.attack_cooldown_timer = 0.0
		player._try_attack()
		kinds.append([player.strike_kind, player.strike_damage])
	assert(kinds == [["", 1], ["", 1], ["finisher", 2]] and player.combo == 0)
	player.attack_cooldown_timer = 0.0
	player.combo_timer = 0.0
	player.since_dash = 0.1
	player._try_attack()
	assert(player.strike_kind == "dash" and player.strike_damage == 2)

	# Rafale de plumes : trois plumes, mais un ennemi n'est touche qu'une fois par rafale ; puis recharge.
	var dummy: BaseMob = load("res://scripts/combat/bestiary.gd").make("lundi/mouton")
	arena.add_child(dummy)
	for mob in arena._alive_mobs():
		if mob != dummy:
			mob.queue_free()
	await process_frame
	dummy.set_physics_process(false)
	dummy.hp = 50
	dummy.max_hp = 50
	player.facing = Vector2.RIGHT
	dummy.global_position = player.global_position + Vector2(70, 0)
	assert(player._try_special() and not player._try_special() and player.special_timer > 0.0)
	var feathers := arena.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("feather.gd"))
	assert(feathers.size() == 3)
	for i in 30:
		await physics_frame
	assert(dummy.hp == 50 - player.attack_damage)

	# Fuite : deux appuis, des pieces en moins, et les PV perdus le restent.
	gs.coins = 10
	player.hp = player.max_hp - 1
	arena._try_flee()
	assert(not arena.combat_over and gs.coins == 10)
	arena._try_flee()
	assert(arena.combat_over and gs.coins == 10 - gs.FLEE_COST and gs.hp_lost == 1 and not gs.in_combat)
	await create_timer(1.0).timeout
	# Gardien sans boss (etage 1) : une meute menee par une elite, qu'on ne fuit pas non plus.
	gs.hp_lost = 0
	assert(not gs.floor_has_boss(1) and gs.floor_has_boss(2) and gs.floor_has_boss(gs.floor_count() - 1))
	assert(gs.floor_has_boss(-3) and not gs.floor_has_boss(-2) and gs.floor_has_boss(gs.MIN_FLOOR_INDEX))
	gs.start_guardian_fight(false)
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	assert(not current_scene.is_boss_fight and current_scene.had_elite and current_scene._alive_mobs().size() >= 1)
	current_scene._try_flee()
	current_scene._try_flee()
	assert(not current_scene.combat_over and not current_scene.boss_bar.visible)
	# On ne fuit pas un boss gardien (etage 2).
	gs.floor_index = 2
	gs.start_guardian_fight(false)
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	current_scene._try_flee()
	current_scene._try_flee()
	assert(not current_scene.combat_over and gs.coins == 10 - gs.FLEE_COST)
	assert(current_scene.is_boss_fight and current_scene.boss_bar.visible)
	gs.guardian_fight = false

	# Cauchemar errant pris a revers : il mene le combat, et les ennemis commencent etourdis.
	gs.floor_index = 1
	gs.encounter_lead = "lundi/bailleur"
	gs.ambush = true
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	var lead = current_scene._alive_mobs()[0]
	assert(lead.get_script().resource_path.ends_with("lundi/bailleur.gd"))
	assert(current_scene._alive_mobs().all(func(m): return m.state == BaseMob.State.COOLDOWN))
	assert(gs.encounter_lead == "" and not gs.ambush)

	print("test_progression OK")
	quit()
