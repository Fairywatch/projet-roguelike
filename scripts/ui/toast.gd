class_name Toast
extends PanelContainer

# Message court du jeu (objet ramasse, PNJ, regle de la nuit...) : une bulle a la taille du texte,
# centree en bas de l'ecran (ou en haut, en combat), qui apparait en douceur puis s'efface.

const MAX_WIDTH := 420.0
const MARGIN := 22.0  # distance au bord de l'ecran

var label := Label.new()
var at_top := false
var top_y := 60.0
var serial := 0
var tween: Tween

func _ready() -> void:
	theme_type_variation = &"Toast"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	visible = false
	minimum_size_changed.connect(_place, CONNECT_DEFERRED)

# duration <= 0 : le message reste jusqu'au suivant (ou jusqu'a hide_now()).
func say(text: String, duration: float = 4.0) -> void:
	serial += 1
	var my := serial
	label.text = text
	var font := label.get_theme_font("font")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	label.custom_minimum_size.x = minf(ceilf(width) + 2.0, MAX_WIDTH)
	var was_visible := visible and modulate.a > 0.5
	visible = true
	_place()
	if tween:
		tween.kill()
	pivot_offset = size / 2.0
	if not was_visible:
		modulate.a = 0.0
		scale = Vector2(0.92, 0.92)
	tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(duration, false).timeout
	if my == serial:
		hide_now()

func hide_now() -> void:
	serial += 1
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): visible = false)

func _place() -> void:
	reset_size()
	pivot_offset = size / 2.0
	var screen := get_viewport_rect().size
	position = Vector2(roundf((screen.x - size.x) / 2.0), top_y if at_top else screen.y - size.y - MARGIN)
