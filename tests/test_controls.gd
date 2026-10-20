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
	await process_frame
	panel.waiting_action = "attack"
	panel.waiting_gamepad = false
	await _send(_key(KEY_U))
	await _send(_key(KEY_U, false))
	assert(Controls.keys["attack"] == KEY_U and panel.waiting_action == "")
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
