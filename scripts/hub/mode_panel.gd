class_name ModePanel
extends MenuPanel

# Entree d'une tour du hub : la nuit se joue en Normal ou en Cauchemar (GameState.nightmare_mode).

signal chosen(nightmare: bool)

var tower_index := 0

func build() -> void:
	add_title(Towers.title(tower_index))
	add_button("Normal", _choose.bind(false))
	add_note("Moins d'ennemis par combat, des ennemis qui laissent le temps de souffler.")
	add_button("Cauchemar", _choose.bind(true))
	add_note("La nuit dans toute sa dureté, pour qui connaît déjà ses rêves.")

func _choose(nightmare: bool) -> void:
	chosen.emit(nightmare)
	queue_free()  # sans `closed` : on part dans la tour, le hub ne doit pas rendre la main
