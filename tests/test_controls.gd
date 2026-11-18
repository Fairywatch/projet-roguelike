# Lancer : godot --headless --path . --script res://tests/test_controls.gd
extends SceneTree

func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await process_frame

func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev

func _pad(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	return ev

# Le panneau tient dans l'ecran, a la taille de son contenu (sans vide sous Retour).
func _assert_fits(panel: Control) -> void:
	var screen := panel.get_viewport_rect().size
	assert(panel.position.y >= 0 and panel.position.y + panel.size.y <= screen.y)
	assert(panel.size.y <= panel.get_combined_minimum_size().y + 1)

func _initialize() -> void:
	await process_frame
	Controls.path = "user://test_controls.cfg"  # ne touche pas aux touches du joueur
	Controls.reset()

	# Clavier et manette declenchent les memes actions ; le stick deplace.
	await _send(_key(KEY_J))
	assert(Input.is_action_pressed("attack"))
	await _send(_key(KEY_J, false))
	await _send(_pad(JOY_BUTTON_X))
	assert(Input.is_action_pressed("attack") and Controls.using_gamepad)
	assert(Controls.name_of("attack") == "X" and Controls.name_of("move") == "Stick")
	await _send(_pad(JOY_BUTTON_X, false))
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	await _send(stick)
	assert(Controls.move_vector().x > 0.9)
	stick.axis_value = 0.0
	await _send(stick)

	# Menus a la manette : A valide, B revient.
	await _send(_pad(JOY_BUTTON_A))
	assert(Input.is_action_pressed("ui_accept"))
	await _send(_pad(JOY_BUTTON_A, false))
	await _send(_pad(JOY_BUTTON_B))
	assert(Input.is_action_pressed("ui_cancel"))
	await _send(_pad(JOY_BUTTON_B, false))

	# Passer du clavier a la manette reecrit les aides (signal), une fois par changement.
	var gs = root.get_node("GameState")
	var changes := [0]
	gs.input_device_changed.connect(func(): changes[0] += 1)
	await _send(_key(KEY_J))
	await _send(_key(KEY_J, false))
	assert(changes[0] == 1 and not Controls.using_gamepad and Controls.name_of("attack") == "J")
	await _send(_pad(JOY_BUTTON_X))
	await _send(_pad(JOY_BUTTON_X, false))
	assert(changes[0] == 2 and Controls.using_gamepad)

	# Noms des boutons selon la manette (Godot les numerote par position).
	assert(Controls.style_of("PS5 Controller") == "playstation" and Controls.style_of("DualShock 4") == "playstation")
	assert(Controls.style_of("Nintendo Switch Pro Controller") == "nintendo" and Controls.style_of("Xbox Series Controller") == "xbox")
	Controls.pad_style = "playstation"
	assert(Controls.name_of("attack") == "Carré" and Controls.name_of("interact") == "Croix" and Controls.name_of("special") == "R1")
	Controls.pad_style = "nintendo"
	assert(Controls.name_of("attack") == "Y" and Controls.name_of("interact") == "B")
	Controls.pad_style = "xbox"
	Controls.rumble(0.6)  # sans manette branchee : ne fait rien, sans erreur

	# Manette debranchee en jouant : pause jusqu'au prochain appui.
	assert(not paused)
	gs.pad_watch.disconnected()
	assert(paused and gs.pad_watch.pause_panel.visible)
	await _send(_pad(JOY_BUTTON_A))
	await _send(_pad(JOY_BUTTON_A, false))
	assert(not paused and not gs.pad_watch.pause_panel.visible)

	# Changer une touche dans le menu : clic sur le bouton, puis la nouvelle touche.
	var panel := ControlsPanel.new()
	root.add_child(panel)
	for i in 4:
		await process_frame
	_assert_fits(panel)
	panel.waiting_action = "attack"
	panel.waiting_gamepad = false
	await _send(_key(KEY_U))
	await _send(_key(KEY_U, false))
	assert(Controls.keys["attack"] == KEY_U and panel.waiting_action == "")
	for i in 4:
		await process_frame
	_assert_fits(panel)  # apres reconstruction aussi
	# Le contenu change de hauteur apres coup (texte a la ligne mesure d'abord sans sa largeur) :
	# le panneau se recentre, sinon il deborde de l'ecran (vu chez un testeur).
	var note: Label = panel.box.get_children().filter(func(c): return c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF)[0]
	for extra in [60, 0]:
		note.custom_minimum_size.y = extra
		for i in 3:
			await process_frame
		_assert_fits(panel)
	await _send(_key(KEY_U))
	assert(Input.is_action_pressed("attack"))
	await _send(_key(KEY_U, false))
	await _send(_key(KEY_J))
	assert(not Input.is_action_pressed("attack"))
	await _send(_key(KEY_J, false))
	# Annuler : Echap ; un bouton manette quand on attend une touche clavier (sinon, a la manette
	# seule, on resterait coince) ; ou attendre.
	panel.waiting_action = "dash"
	await _send(_pad(JOY_BUTTON_Y))
	assert(panel.waiting_action == "" and Controls.keys["dash"] == KEY_K and Controls.pads["active"] == JOY_BUTTON_Y)
	await _send(_pad(JOY_BUTTON_Y, false))
	panel.waiting_action = "dash"
	await _send(_key(KEY_ESCAPE))
	assert(panel.waiting_action == "" and Controls.keys["dash"] == KEY_K)
	await _send(_key(KEY_ESCAPE, false))
	panel.waiting_action = "dash"
	panel.waiting_gamepad = true
	panel.waited = ControlsPanel.CANCEL_AFTER
	await process_frame
	assert(panel.waiting_action == "" and Controls.pads["dash"] == JOY_BUTTON_B)
	# Bouton manette, sauvegarde et rechargement.
	panel.waiting_action = "dash"
	panel.waiting_gamepad = true
	await _send(_pad(JOY_BUTTON_RIGHT_SHOULDER))
	assert(Controls.pads["dash"] == JOY_BUTTON_RIGHT_SHOULDER)
	Controls.pads["dash"] = JOY_BUTTON_A
	Controls.setup()
	assert(Controls.pads["dash"] == JOY_BUTTON_RIGHT_SHOULDER and Controls.keys["attack"] == KEY_U)

	Controls.reset()
	assert(Controls.keys["attack"] == KEY_J and Controls.pads["dash"] == JOY_BUTTON_B)
	print("test_controls OK")
	quit()
