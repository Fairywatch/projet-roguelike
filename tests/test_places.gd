# Lancer : godot --headless --path . --script res://tests/test_places.gd
# Lieux des nuits (scripts/visual/places.gd, docs/nuits.md) : tuiles, decors, regles d'etage.
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"

	# Chaque lieu a toutes ses tuiles (reve et cauchemar) et tous ses decors.
	for night in Places.LIST:
		for family in [FloorGenerator.Family.PARADOXAL, FloorGenerator.Family.PROFOND]:
			for intensity in [FloorGenerator.Intensity.REVE, FloorGenerator.Intensity.CAUCHEMAR]:
				var theme := DreamTheme.theme_name(family, intensity, night)
				assert(theme.begins_with(night + "/"))
				assert(DreamTheme.floor_textures(theme).all(func(t): return t != null))
				assert(DreamTheme.wall_texture(theme, "top") != null and DreamTheme.wall_texture(theme, "face") != null)
			for decor_name in DreamTheme.decor_names(family, night):
				assert(DreamTheme.decor_texture(family, decor_name, night) != null, decor_name)
		assert(Places.rule(night) != null)
	# Une nuit sans lieu propre garde l'habillage d'origine.
	assert(DreamTheme.theme_name(FloorGenerator.Family.PARADOXAL, FloorGenerator.Intensity.REVE, "") == "reve_paradoxal")

	# Lundi : la carte prend la regle, plus forte en fin de nuit ; les paupieres se ferment puis se rouvrent.
	gs.new_run(0)
	gs.floor_index = gs.floor_count() - 1
	var f = gs.get_or_create_floor_data(gs.floor_index)
	f["family"] = FloorGenerator.Family.PARADOXAL
	f["intensity"] = FloorGenerator.Intensity.REVE
	change_scene_to_file("res://scenes/exploration/Map.tscn")
	for i in 10:
		await process_frame
	var map = current_scene
	assert(map.rule != null and is_equal_approx(map.rule.strength, 1.0))
	assert(f["rule_seen"])
	map.rule.blink()
	await create_timer(map.rule.CLOSE_TIME + 0.1).timeout
	assert(map.rule.upper.position.y == 0.0)
	await create_timer(map.rule.CLOSED.y + map.rule.OPEN_TIME + 0.2).timeout
	assert(map.rule.upper.position.y < -100.0)

	# Les decors interactifs portent le nom du lieu.
	gs.hp_lost = 1
	var star := DreamDecor.new()
	star.decor_name = "etoile"
	star.family = FloorGenerator.Family.PARADOXAL
	star.night = "lundi"
	map.generated_root.add_child(star)
	map._on_decor_touched(star)
	assert(map.message_label.text.begins_with("Veilleuse étoile") and gs.hp_lost == 0)
	print("test_places OK")
	quit()
