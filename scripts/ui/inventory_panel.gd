class_name InventoryPanel
extends Label

# Liste des objets passifs, affichee tant que la touche des passifs est enfoncee (carte et arene).

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.92)
	style.border_color = Color(0.6, 0.5, 0.9, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("normal", style)
	add_theme_font_size_override("font_size", 11)
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(420, 0)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false

func _process(_delta: float) -> void:
	var show_panel := Input.is_action_pressed("inventory")
	if show_panel and not visible:
		text = "Objets passifs (%d)\n\n%s" % [GameState.passive_count(), GameState.passives_detail()]
		reset_size()
		position = (get_viewport_rect().size - size) / 2.0
	visible = show_panel
