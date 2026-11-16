# Lancer : godot --headless --path . --script res://tests/test_slots.gd
# Sauvegardes : trois emplacements independants, qu'on choisit et qu'on peut effacer.
extends SceneTree

const DIR := "user://test_slots/"

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame
	# Dossier a part : le test ne touche ni aux vraies sauvegardes ni a l'emplacement retenu.
	DirAccess.make_dir_recursive_absolute(DIR)
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)
	gs.save_dir = DIR
	gs.slot = 0
	gs._use_slot_paths()
	gs._reset_state()
	assert(gs.slot_paths(0) == [DIR + "run.save", DIR + "meta.save"] and gs.slot_paths(2) == [DIR + "run_3.save", DIR + "meta_3.save"])
	for i in gs.SLOT_COUNT:
		assert(gs.slot_summary(i) == "")

	# Sauvegarde 1 : une partie en cours, des pieces, une amelioration.
	gs.coins = 120
	gs.buy_upgrade("coeur")
	gs.completed_towers = ["lundi"]
	gs.unlocked_towers = 2
	gs.new_run(1)
	gs.floor_index = 3
	gs.take_item("plume_de_reve")
	gs.save_run()
	assert(gs.slot_summary(0) == "Semaine 1  ·  1/7 nuits  ·  80 pièces  ·  Mardi, étage 3")

	# Sauvegarde 2 : vide, donc une nouvelle partie ; la sauvegarde 1 n'a pas bouge.
	gs.select_slot(1)
	assert(gs.slot == 1 and gs.coins == 0 and not gs.run_started and gs.upgrades.is_empty() and gs.passive_count() == 0)
	assert(gs.unlocked_towers == 1 and gs.completed_towers.is_empty() and gs.max_hp() == gs.BASE_MAX_HP)
	gs.coins = 7
	gs.select_slot(0)
	assert(gs.coins == 80 and gs.run_started and gs.tower_index == 1 and gs.floor_index == 3)
	assert(gs.upgrade_level("coeur") == 1 and gs.passive_items == {"plume_de_reve": 1} and gs.mod("max_hp") == 1)
	assert(gs.slot_summary(1) == "Semaine 1  ·  0/7 nuits  ·  7 pièces")
	# L'emplacement choisi est retenu pour le prochain lancement du jeu.
	gs.select_slot(2)
	assert(gs._read_slot() == 2)

	# Effacer : une autre sauvegarde (la 2), puis celle en cours (retour a zero).
	gs.erase_slot(1)
	assert(gs.slot_summary(1) == "" and gs.slot_summary(0) != "")
	gs.select_slot(0)
	gs.erase_slot(0)
	assert(gs.slot_summary(0) == "" and gs.coins == 0 and not gs.run_started and gs.upgrades.is_empty())
	assert(not FileAccess.file_exists(DIR + "run.save"))

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)
	print("test_slots OK")
	quit()
