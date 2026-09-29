extends CanvasLayer

# Transitions entre scenes. Style selon le type d'etage (GDD section 4) :
#   SOFT   : sommeil paradoxal, l'ecran ondule et se fond dans une teinte de reve ;
#   BRUTAL : sommeil profond, noir saccade (fondu simple si les flashs sont desactives) ;
#   DEFAULT: fondu au noir.

enum Style { DEFAULT, SOFT, BRUTAL }

const WaveShader := preload("res://assets/shaders/dream_wave.gdshader")

@onready var overlay: ColorRect = $Overlay

var wave := ColorRect.new()

func _ready() -> void:
	wave.set_anchors_preset(Control.PRESET_FULL_RECT)
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.material = ShaderMaterial.new()
	wave.material.shader = WaveShader
	wave.visible = false
	add_child(wave)

# Style selon la famille de l'etage courant.
static func style_for_family(family: int) -> Style:
	return Style.SOFT if family == FloorGenerator.Family.PARADOXAL else Style.BRUTAL

func change_scene(path: String, style: Style = Style.DEFAULT) -> void:
	if style == Style.BRUTAL and not Settings.enabled("flashes"):
		style = Style.DEFAULT
	match style:
		Style.SOFT:
			await _soft(path)
		Style.BRUTAL:
			await _brutal(path)
		_:
			await _fade(path)

func _fade(path: String) -> void:
	var tween_out := create_tween()
	tween_out.tween_property(overlay, "modulate:a", 1.0, 0.35)
	await tween_out.finished
	await _switch(path)
	var tween_in := create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 0.35)

func _soft(path: String) -> void:
	var material: ShaderMaterial = wave.material
	wave.visible = true
	var tween_out := create_tween()
	tween_out.tween_method(func(v: float): material.set_shader_parameter("progress", v), 0.0, 1.0, 0.7)
	await tween_out.finished
	await _switch(path)
	var tween_in := create_tween()
	tween_in.tween_method(func(v: float): material.set_shader_parameter("progress", v), 1.0, 0.0, 0.5)
	await tween_in.finished
	wave.visible = false

func _brutal(path: String) -> void:
	var tween_out := create_tween()
	for a in [1.0, 0.2, 1.0, 0.5, 1.0]:
		tween_out.tween_property(overlay, "modulate:a", a, 0.05)
	await tween_out.finished
	await _switch(path)
	var tween_in := create_tween()
	tween_in.tween_interval(0.1)
	tween_in.tween_property(overlay, "modulate:a", 0.0, 0.15)

func _switch(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
