class_name SpeedrunTimer
extends Label

# Chrono du mode speedrun, en haut au centre (carte et arene). Rouge dans les 30 dernieres secondes.

const WARNING_TIME := 30.0

func _ready() -> void:
	add_theme_font_size_override("font_size", 13)
	add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	add_theme_constant_override("outline_size", 4)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -60
	offset_right = 60
	offset_top = 26
	offset_bottom = 44

func _process(_delta: float) -> void:
	visible = GameState.speedrun and GameState.run_started
	if not visible:
		return
	text = "Réveil dans " + GameState.format_time(GameState.time_left)
	var urgent := GameState.time_left < WARNING_TIME
	add_theme_color_override("font_color", Color(1, 0.35, 0.35) if urgent else Color(1, 0.95, 0.8))
