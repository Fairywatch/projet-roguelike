# Lancer : godot --headless --path . --script res://tests/test_item_rules.gd
# Regles des objets : PV max plafonnes, legendaires uniques par nuit, butin de combat limite par
# etage, maledictions (objets maudits deguises en objets mysteres), fiche de stats, et l'Autre Soi
# qui copie le joueur.
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.upgrades = {}  # la vraie sauvegarde est deja chargee : pas d'ameliorations ni de semaine 2 ici
	gs.week = 1
	gs.start_bag.clear()
	gs.new_run(0)

	# PV max plafonnes, quel que soit le nombre de coeurs ramasses.
	for i in 10:
		gs.take_item("plume_de_reve")
	assert(gs.max_hp() == gs.MAX_HP_CAP and gs.current_hp() == gs.MAX_HP_CAP)
	gs.new_run(0)

	# Chaque legendaire ne tombe qu'une fois par nuit ; ensuite le butin redescend d'un cran.
	gs.floor_index = gs.floor_count() - 1
	var legendaries := Items.PASSIVES.filter(func(item): return item["rarity"] == Items.LEGENDAIRE).map(func(item): return item["id"])
	var seen := {}
	for i in 400:
		var id: String = gs.roll_item_id(1.0)
		if id in legendaries:
			assert(not seen.has(id))
			seen[id] = true
	assert(seen.size() == legendaries.size() and gs.legendaries_seen.size() == legendaries.size())
	for i in 50:
		assert(gs.roll_item_id(1.0) not in legendaries)
	# Apres une mort, un legendaire perdu peut retomber ; celui reste au sol, non.
	gs.current_floor()["ground_items"].append({"id": legendaries[0], "pos": Vector2.ZERO})
	gs.apply_death_setback()
	gs.floor_index = 0
	gs.current_floor()["ground_items"].append({"id": legendaries[1], "pos": Vector2.ZERO})
	gs.apply_death_setback()
	assert(gs.legendaries_seen == [legendaries[1]])
	gs.new_run(0)
	assert(gs.legendaries_seen.is_empty())

	# Butin de combat : au plus COMBAT_ITEMS_PER_FLOOR objets par etage.
	assert(gs.combat_items_left() == gs.COMBAT_ITEMS_PER_FLOOR)
	gs.current_floor()["combat_items"] = gs.COMBAT_ITEMS_PER_FLOOR
	assert(gs.combat_items_left() == 0)
	gs.floor_index = 1
	assert(gs.combat_items_left() == gs.COMBAT_ITEMS_PER_FLOOR)

	# Butin mystere : une part cachee, dont environ la moitie de maledictions.
	var hidden := 0
	var cursed := 0
	for i in 3000:
		var drop: Dictionary = gs.roll_drop()
		if drop["hidden"]:
			hidden += 1
			cursed += int(Items.is_curse(drop["id"]))
		else:
			assert(not Items.is_curse(drop["id"]))
	assert(hidden > 450 and hidden < 750 and cursed > hidden * 0.35 and cursed < hidden * 0.65)
	gs.legendaries_seen.clear()

	# Malediction : ses effets s'ajoutent, puis elle s'efface au bout de CURSE_FLOORS etages.
	gs.new_run(0)
	assert(gs.take_item("coeur_fele") == "" and gs.passive_count() == 0)
	assert(gs.curses.size() == 1 and gs.mod("enemy_damage") == 1)
	gs.take_item("poches_trouees")
	assert(gs.roll_drop().is_empty())
	for i in Items.CURSE_FLOORS - 1:
		gs.advance_floor()
	assert(gs.curses.size() == 2)
	gs.advance_floor()
	assert(gs.curses.is_empty() and gs.mod("enemy_damage") == 0 and not gs.roll_drop().is_empty())
	gs.take_item("cauchemar_tenace")
	gs.apply_death_setback()  # la mort efface aussi les maledictions
	assert(gs.curses.is_empty() and gs.mod("enemy_hp") == 0)
	# Un objet mystere au sol ne dit pas ce qu'il cache.
	var pickup = load("res://scripts/items/item_pickup.gd").new()
	pickup.item_id = "ombre_jumelle"
	pickup.mystery = true
	root.add_child(pickup)
	await process_frame
	assert(pickup.label.text == Items.MYSTERY["name"])
	pickup.free()

	# Coeur fele : un coup ennemi fait 2 degats.
	gs.new_run(0)
	gs.take_item("plume_de_reve")
	gs.take_item("plume_de_reve")
	gs.take_item("coeur_fele")
	var player = load("res://scenes/combat/PlayerCombat.tscn").instantiate()
	root.add_child(player)
	await process_frame
	assert(player.hp == 5)
	player.take_damage()
	assert(player.hp == 3)
	player.free()

	# Fiche de stats : PV, degats, et les effets des objets portes.
	gs.new_run(0)
	gs.take_item("miroir_de_poche")
	var lines: Dictionary = {}
	for line in load("res://scripts/combat/player_stats.gd").lines():
		lines[line[0]] = line[1]
	assert(lines.has("PV") and lines["Dégâts"].begins_with("1 ") and lines["Esquive"] == "+15 %")

	# L'Autre Soi copie le joueur : PV max, degats, esquive, coups bloques, portee, objet actif.
	gs.new_run(0)
	gs.take_item("coeur_de_lune")  # +2 PV max, +1 degat
	gs.take_item("doudou_protecteur")
	gs.take_item("bras_de_morphee")
	gs.take_item("reveil_strident")
	var mirror = Bestiary.make("mercredi/autre_soi")
	root.add_child(mirror)
	await process_frame
	assert(mirror.hp == ceili(46 * (0.7 + 0.1 * 5)) and mirror.slash_damage == 2)
	assert(mirror.shield == 1 and mirror.evasion == 0.0 and mirror.active == "reveil_strident")
	assert(mirror.slash_radius > mirror.SLASH_RADIUS)
	# Ses coups bloques et son esquive jouent contre le joueur.
	mirror.evasion = 0.0
	var before: int = mirror.hp
	mirror.take_hit(1)
	assert(mirror.hp == before and mirror.shield == 0)
	mirror.take_hit(1)
	assert(mirror.hp == before - 1)
	mirror.free()

	# Partie commencee avec une version plus ancienne : un etage enregistre sans "combat_items"
	# recoit la cle a la lecture, et une victoire avec butin ne plante pas.
	gs.new_run(0)
	gs.floor_index = 1
	gs.floor_data_by_index[1] = {"seed": 5, "family": 0, "intensity": 0, "wins": 2, "opened_chests": ["a"], "ground_items": [], "used_decor": []}
	assert(gs.current_floor()["combat_items"] == 0 and gs.current_floor()["wins"] == 2 and gs.current_floor()["opened_chests"] == ["a"])
	gs.floor_data_by_index[1].erase("combat_items")
	change_scene_to_file("res://scenes/combat/CombatArena.tscn")
	for i in 10:
		await process_frame
	var arena = current_scene
	arena.had_elite = true  # butin garanti
	for mob in arena._alive_mobs():
		mob.take_hit(99)
	await create_timer(0.5).timeout
	assert(arena.combat_over and gs.current_floor()["wins"] == 3 and gs.current_floor()["combat_items"] == 1)
	# Les listes d'un etage ne sont pas partagees avec le suivant.
	gs.current_floor()["opened_chests"].append("b")
	assert(gs.get_or_create_floor_data(2)["opened_chests"].is_empty())

	print("test_item_rules OK")
	quit()
