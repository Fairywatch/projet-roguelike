class_name TowerPanel
extends MenuPanel

# Choix de la nuit (tour) a explorer. Les nuits se debloquent en terminant la precedente.

signal tower_chosen(index: int, speedrun: bool)

var speedrun := false

func build() -> void:
	add_title("Choisis ta nuit")
	var toggle := CheckButton.new()
	toggle.text = "Mode speedrun (le reveil sonne a la fin du chrono)"
	toggle.button_pressed = speedrun
	toggle.add_theme_font_size_override("font_size", 11)
	toggle.toggled.connect(func(on): speedrun = on)
	box.add_child(toggle)
	for i in Towers.LIST.size():
		var tower: Dictionary = Towers.LIST[i]
		var unlocked := i < GameState.unlocked_towers
		var label := "%s  (%d etages)" % [tower["name"], tower["floors"]] if unlocked else "???  (verrouillee)"
		var button := add_button(label, func(): tower_chosen.emit(i, speedrun))
		button.disabled = not unlocked
		var note: String = tower["desc"] if unlocked else "Termine la nuit precedente pour la debloquer."
		if GameState.best_times.has(tower["id"]):
			note += "  Record speedrun : %s" % GameState.format_time(GameState.best_times[tower["id"]])
		add_note(note)
	if GameState.run_started:
		add_note("Commencer une nouvelle nuit abandonne la partie en cours.", Color(1, 0.75, 0.6))
