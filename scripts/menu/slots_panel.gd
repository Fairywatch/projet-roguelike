class_name SlotsPanel
extends MenuPanel

# Sauvegardes : trois emplacements independants (GameState.select_slot / erase_slot). On en choisit
# un pour y jouer ; "Effacer" le remet a zero, apres confirmation, pour y commencer une autre partie.

var confirm_erase := -1  # emplacement dont l'effacement attend un deuxieme appui

func build() -> void:
	add_title("Sauvegardes")
	GameState.save_run()  # le resume de la sauvegarde en cours doit etre a jour
	for i in GameState.SLOT_COUNT:
		var summary := GameState.slot_summary(i)
		var current := i == GameState.slot
		var label := "%d  -  %s%s" % [i + 1, summary if summary != "" else "Vide : nouvelle partie", "   (en cours)" if current else ""]
		var choose := add_button(label, _select.bind(i))
		choose.add_theme_font_size_override("font_size", 11)
		if current:
			choose.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
		var erase_label := "Appuie encore pour effacer la sauvegarde %d" % (i + 1) if confirm_erase == i else "Effacer la sauvegarde %d" % (i + 1)
		var erase := add_button(erase_label, _erase.bind(i))
		erase.add_theme_font_size_override("font_size", 9)
		erase.custom_minimum_size.y = 16
		erase.disabled = summary == ""
		if confirm_erase == i:
			erase.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	add_note("Chaque sauvegarde garde sa propre progression : pièces, nuits terminées, améliorations et nuit en cours. Effacer une sauvegarde la remet à zéro.")

func _select(index: int) -> void:
	if index != GameState.slot:
		GameState.select_slot(index)
	_reload_menu()

func _erase(index: int) -> void:
	if confirm_erase != index:
		confirm_erase = index
		rebuild()
		return
	confirm_erase = -1
	GameState.erase_slot(index)
	if index == GameState.slot:
		_reload_menu()
	else:
		rebuild()

# Le menu se recharge pour montrer la sauvegarde choisie (bouton Continuer, pieces...).
func _reload_menu() -> void:
	get_tree().change_scene_to_file.call_deferred(GameState.MENU_PATH)
