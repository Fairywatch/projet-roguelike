class_name TowerPanel
extends MenuPanel

# Choix de la nuit (tour) a explorer. Les nuits se debloquent en terminant la precedente.

signal tower_chosen(index: int)

func build() -> void:
	add_title("Choisis ta nuit")
	for i in Towers.LIST.size():
		var tower: Dictionary = Towers.LIST[i]
		var unlocked := i < GameState.unlocked_towers
		var label := "%s  (%d etages)" % [tower["name"], tower["floors"]] if unlocked else "???  (verrouillee)"
		var button := add_button(label, tower_chosen.emit.bind(i))
		button.disabled = not unlocked
		add_note(tower["desc"] if unlocked else "Termine la nuit precedente pour la debloquer.")
	if GameState.run_started:
		add_note("Commencer une nouvelle nuit abandonne la partie en cours.", Color(1, 0.75, 0.6))
