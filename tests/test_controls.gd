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
	# Echap annule ; un bouton manette ne remplace pas une touche clavier.
	panel.waiting_action = "dash"
	await _send(_pad(JOY_BUTTON_Y))
	assert(panel.waiting_action == "dash")
	await _send(_key(KEY_ESCAPE))
	assert(panel.waiting_action == "" and Controls.keys["dash"] == KEY_K)
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
