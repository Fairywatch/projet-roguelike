class_name SettingsPanel
extends MenuPanel

# Onglet Parametres du menu : un curseur par volume (Settings.SLIDERS), une case par option (Settings.LABELS).

func build() -> void:
	add_title("Parametres")
	add_button("Touches (clavier et manette)", _open_controls)
	for option in Settings.SLIDERS:
		_add_slider(option)
	for option in Settings.LABELS:
		var check := CheckButton.new()
		check.text = Settings.LABELS[option]
		check.button_pressed = Settings.enabled(option)
		check.add_theme_font_size_override("font_size", 12)
		check.toggled.connect(func(on): Settings.set_option(option, on))
		box.add_child(check)
		# Lance depuis l'editeur, le jeu est integre a l'onglet "Jeu" : pas de plein ecran possible.
		if option == "fullscreen" and Engine.is_embedded_in_editor():
			check.disabled = true
			add_note("Indisponible quand le jeu tourne dans l'onglet Jeu de l'editeur")

func _open_controls() -> void:
	var panel := ControlsPanel.new()
	visible = false
	set_process_unhandled_input(false)  # Echap ne doit fermer que le panneau des touches
	panel.closed.connect(func():
		visible = true
		set_process_unhandled_input(true)
		rebuild())
	get_parent().add_child(panel)

func _add_slider(option: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = Settings.SLIDERS[option]
	label.custom_minimum_size.x = 120
	label.add_theme_font_size_override("font_size", 12)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.volume(option)
	slider.custom_minimum_size.x = 170
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var percent := Label.new()
	percent.custom_minimum_size.x = 44
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.add_theme_font_size_override("font_size", 12)
	percent.text = "%d %%" % roundi(slider.value * 100)
	slider.value_changed.connect(func(value: float):
		percent.text = "%d %%" % roundi(value * 100)
		Settings.set_option(option, value)
		if option == "sfx_volume":
			Sound.play("ui_select"))  # apercu du nouveau volume
	row.add_child(label)
	row.add_child(slider)
	row.add_child(percent)
	box.add_child(row)
