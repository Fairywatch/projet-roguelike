# Lancer : godot --headless --path . --script res://tests/test_scenes.gd
# Charge chaque scene jouable quelques frames, avec des fichiers de sauvegarde de test
# (lancer directement une scene utiliserait la vraie sauvegarde du joueur).
extends SceneTree

const SCENES := [
	"res://scenes/menu/MainMenu.tscn",
	"res://scenes/hub/Hub.tscn",
	"res://scenes/story/Cutscene.tscn",
	"res://scenes/exploration/Map.tscn",
	"res://scenes/combat/CombatArena.tscn",
]

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	# Chaque effet du manifeste a bien tous ses fichiers de variantes.
	for sfx_name in SfxManifest.SFX:
		for i in SfxManifest.SFX[sfx_name]["variants"]:
			assert(ResourceLoader.exists("%s%s_%d.ogg" % [Sound.SFX_DIR, sfx_name, i]))
	for tower in Towers.LIST.size():
		gs.new_run(tower)
		for path in SCENES:
			gs.cutscene_id = "intro"  # la scene de recit a besoin d'une histoire a raconter
			change_scene_to_file(path)
			for i in 30:
				await process_frame
			assert(current_scene != null and current_scene.scene_file_path == path)
	print("test_scenes OK")
	quit()
