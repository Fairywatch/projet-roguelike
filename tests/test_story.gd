# Lancer : godot --headless --path . --script res://tests/test_story.gd
extends SceneTree

const VIGNETTES := ["bed", "thoughts", "towers", "dive", "tower", "dawn"]

func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 3:
		await process_frame

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame  # laisse GameState._ready (chargement de la sauvegarde) passer avant la mise en place
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.new_run(0)

	# Le recit couvre les 7 nuits : une fin et une replique par habitant du reve, pour chacune.
	for panel in Story.INTRO:
		assert(panel["vignette"] in VIGNETTES and panel["text"] != "")
	for tower in Towers.LIST:
		assert(Story.ENDINGS.has(tower["id"]) and not Story.ENDINGS[tower["id"]].is_empty())
		for panel in Story.ENDINGS[tower["id"]]:
			assert(panel["vignette"] in VIGNETTES and panel["text"] != "")
		assert(Story.NPC_LINES[tower["id"]].size() == 3)

	# Finir une nuit : sa fin est racontee avant le retour au menu.
	gs.new_run(2)
	gs.floor_index = gs.floor_count() - 1
	gs.complete_tower()
	assert(gs.cutscene_id == "ending_mercredi" and gs.cutscene_tower == 2)
	assert(gs.after_combat_scene() == gs.CUTSCENE_PATH)

	# La scene deroule tous les tableaux (E) puis enchaine sur la scene suivante.
	change_scene_to_file(gs.CUTSCENE_PATH)
	for i in 10:
		await process_frame
	var cutscene = current_scene
	assert(cutscene.panels.size() == Story.ENDINGS["mercredi"].size())
	for i in cutscene.panels.size() * 2:  # 1er appui : texte complet, 2e : tableau suivant
		await _press(KEY_E)
	assert(cutscene.finishing and gs.cutscene_id == "")
	await create_timer(1.0).timeout
	assert(current_scene.scene_file_path == gs.MENU_PATH)

	# Intro : jouee la premiere fois qu'on va choisir une nuit, puis plus jamais d'office.
	gs.intro_seen = false
	current_scene._open_hub()
	assert(gs.intro_seen and gs.cutscene_id == "intro" and gs.cutscene_next == gs.HUB_PATH)
	await create_timer(1.0).timeout
	await _press(KEY_ESCAPE)  # Echap passe toute l'intro
	await create_timer(1.0).timeout
	assert(current_scene.scene_file_path == gs.HUB_PATH)

	# Habitant du reve : sa replique de la nuit d'abord, la quete ensuite.
	var quest := {"npc": 1, "kind": "chasse", "target": 2, "state": "offered", "start_wins": 0, "carried": false}
	var npc = load("res://scripts/exploration/npc.gd").new()
	npc.quest = quest
	root.add_child(npc)
	await process_frame
	var said := []
	npc.said.connect(func(text): said.append(text))
	npc.talk()
	assert(quest["state"] == "offered" and said[0].contains(Story.NPC_LINES["mercredi"][1]))
	npc.talk()
	assert(quest["state"] == "active")

	print("test_story OK")
	quit()
