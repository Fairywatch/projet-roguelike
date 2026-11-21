class_name TitleBanner
extends Label

# Grand titre au centre de l'ecran ("Victoire !", "Vaincu...") : il surgit en grossissant,
# reste un moment, puis s'efface. Pose dans une couche d'interface (CanvasLayer).

const HOLD := 1.1

static func show_text(layer: Node, text: String, color: Color, hold: float = HOLD) -> TitleBanner:
	var banner := TitleBanner.new()
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	layer.add_child(banner)
	banner._play(hold)
	return banner

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"PixelTitle"
	add_theme_font_size_override("font_size", 40)
	add_theme_constant_override("outline_size", 9)
	add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.14))
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_left = -200
	offset_right = 200
	offset_top = -50
	offset_bottom = -10

func _play(hold: float) -> void:
	pivot_offset = Vector2(200, 20)
	scale = Vector2(1.6, 1.6)
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.chain().tween_interval(hold)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(queue_free)
