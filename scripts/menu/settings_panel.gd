class_name SettingsPanel
extends MenuPanel

# Onglet Parametres du menu : une case a cocher par option de Settings.LABELS.

func build() -> void:
	add_title("Parametres")
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
