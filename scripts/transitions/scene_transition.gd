extends CanvasLayer

@onready var overlay: ColorRect = $Overlay

func change_scene(path: String) -> void:
	var tween_out := create_tween()
	tween_out.tween_property(overlay, "modulate:a", 1.0, 0.35)
	await tween_out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var tween_in := create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 0.35)
