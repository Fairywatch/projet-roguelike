class_name ControlsPanel
extends MenuPanel

# Parametres > Touches : une ligne par commande, un bouton pour la touche clavier et un pour le
# bouton manette. Cliquer puis appuyer sur la nouvelle touche. Annuler : Echap, un bouton manette
# quand on attend une touche clavier, ou attendre CANCEL_AFTER secondes.

const CANCEL_AFTER := 5.0

var waiting_action := ""
var waiting_gamepad := false
var waited := 0.0

func build() -> void:
	add_title("Touches")
	var grid := GridContainer.new()
	grid.columns = 6  # deux commandes par ligne : les 10 tiennent dans l'ecran
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	for action in Controls.ACTIONS:
		var label := Label.new()
		label.text = Controls.ACTIONS[action][0]
		label.custom_minimum_size.x = 76
		label.add_theme_font_size_override("font_size", 15)
		grid.add_child(label)
		grid.add_child(_bind_button(action, false))
		grid.add_child(_bind_button(action, true))
	box.add_child(grid)
	add_note("Les flèches et le stick gauche déplacent toujours. Dans les menus, %s valide et %s revient. Pour annuler un changement : Échap, ou attendre 5 secondes." % [Controls.button_name(JOY_BUTTON_A), Controls.button_name(JOY_BUTTON_B)])
	add_button("Touches par défaut", func(): Controls.reset(); rebuild())

func _bind_button(action: String, gamepad: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size.x = 74
	button.add_theme_font_size_override("font_size", 15)  # 10 lignes : doit tenir dans l'ecran
	button.text = Controls.pad_name(action) if gamepad else Controls.key_name(action)
	if action == waiting_action and gamepad == waiting_gamepad:
		button.text = "Appuie..."
	button.pressed.connect(func():
		Sound.play("ui_select")
		waiting_action = action
		waiting_gamepad = gamepad
		waited = 0.0
		button.text = "Appuie...")
	return button

func _process(delta: float) -> void:
	if waiting_action == "":
		return
	waited += delta
	if waited >= CANCEL_AFTER:
		waiting_action = ""
		waited = 0.0
		rebuild()

# _input (avant les boutons) : la touche choisie ne doit pas aussi activer le bouton qui a le focus.
func _input(event: InputEvent) -> void:
	if waiting_action == "" or not event.is_pressed() or event.is_echo():
		return
	# Une touche clavier attendue : un bouton manette annule (sinon, a la manette seule, on resterait coince).
	var cancel: bool = (event is InputEventKey and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and not waiting_gamepad)
	var fits: bool = event is InputEventJoypadButton if waiting_gamepad else event is InputEventKey
	if not cancel and not fits:
		return
	get_viewport().set_input_as_handled()
	if not cancel:
		Controls.rebind(waiting_action, event)
	waiting_action = ""
	rebuild()
