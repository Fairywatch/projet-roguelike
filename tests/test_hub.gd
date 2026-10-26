# Lancer : godot --headless --path . --script res://tests/test_hub.gd
extends SceneTree

func _mode_panel(hub: Node) -> ModePanel:
	for child in hub.get_node("UI").get_children():
		if child is ModePanel:
			return child
	return null

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame  # laisse GameState._ready (chargement de la sauvegarde) passer avant la mise en place
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.new_run(0)
	gs.run_started = false
	gs.unlocked_towers = 2
	gs.completed_towers = ["lundi"]

	change_scene_to_file("res://scenes/hub/Hub.tscn")
	for i in 10:
		await process_frame
	var hub = current_scene
	assert(hub.tower_state(0) == "done" and hub.tower_state(1) == "open" and hub.tower_state(2) == "locked")

	# Nuit verrouillee : rien ne se passe.
	hub._set_near("tower_2")
	hub.interact()
	assert(not gs.run_started)
	assert(hub.prompt_label.text.contains("termine d'abord la nuit de Mardi"))

	# L'horloge active le speedrun, qui s'applique a la nuit choisie.
	hub._set_near("clock")
	hub.interact()
	assert(hub.speedrun_choice)
	hub._set_near("tower_1")
	hub.interact()
	assert(not gs.run_started and hub.panel_open)  # d'abord le choix du mode
	_mode_panel(hub).chosen.emit(true)
	assert(gs.run_started and gs.tower_index == 1 and gs.speedrun and gs.nightmare_mode)
	hub.speedrun_choice = false

	# Partie en cours sur Mardi : entrer dans Lundi demande une confirmation.
	await create_timer(1.5).timeout
	change_scene_to_file("res://scenes/hub/Hub.tscn")
	for i in 10:
		await process_frame
	hub = current_scene
	hub._set_near("tower_0")
	hub.interact()
	assert(gs.tower_index == 1 and hub.prompt_label.text.contains("abandonner"))
	hub.interact()
	_mode_panel(hub).chosen.emit(false)
	assert(gs.tower_index == 0 and gs.floor_index == 0 and not gs.nightmare_mode)

	print("test_hub OK")
	quit()
