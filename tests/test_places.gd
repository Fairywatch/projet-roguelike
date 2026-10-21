# Lancer : godot --headless --path . --script res://tests/test_places.gd
# Lieux des nuits (scripts/visual/places.gd, docs/nuits.md) : tuiles, decors, regles d'etage.
extends SceneTree

# Ouvre un etage de la nuit `tower` (famille et intensite imposees), au dernier etage par defaut.
func _open_map(gs, tower: int, family: int = FloorGenerator.Family.PARADOXAL, floor_index: int = -1) -> Node:
	gs.new_run(tower)
	gs.floor_index = gs.floor_count() - 1 if floor_index < 0 else floor_index
	var f = gs.get_or_create_floor_data(gs.floor_index)
	f["family"] = family
	f["intensity"] = FloorGenerator.Intensity.REVE
	change_scene_to_file("res://scenes/exploration/Map.tscn")
	for i in 10:
		await process_frame
	return current_scene

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
	var map = await _open_map(gs, 0)
	assert(map.rule != null and is_equal_approx(map.rule.strength, 1.0))
	assert(gs.current_floor()["rule_seen"])
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
	# Mardi : la pression monte avec le temps passe sur l'etage et accelere les rencontres ; le
	# sablier la fait retomber.
	map = await _open_map(gs, 1)
	var base: float = map.rule.base_chance  # taux sans pression (elle a deja un peu monte)
	map.rule._process(15.0)
	assert(map.rule.pressure > 0.4 and map.encounter_chance > base * 2.0)
	map.rule.on_decor("horloge")
	map.rule._process(0.0)
	assert(map.rule.pressure == 0.0 and is_equal_approx(map.encounter_chance, base))

	# Mercredi : trois leurres au dernier etage ; en prendre un ramene au depart et il ne revient pas.
	map = await _open_map(gs, 2)
	await process_frame
	assert(map.rule.decoys.size() == 3)
	var decoy: Area2D = map.rule.decoys[0]
	map.player.global_position = decoy.global_position + Vector2(200, 0)
	map.rule._on_decoy_entered(map.player, decoy)
	assert(map.player.global_position == map._cell_to_world(map.rule.floor_data.spawn_cell))
	assert(map.rule.decoys.size() == 2 and gs.current_floor()["used_decoys"].size() == 1)
	change_scene_to_file("res://scenes/exploration/Map.tscn")
	for i in 12:
		await process_frame
	assert(current_scene.rule.decoys.size() == 2)

	# Jeudi : trois barrieres au dernier etage, dont une sur le chemin du portail ; un combat gagne
	# sur l'etage les ouvre toutes.
	map = await _open_map(gs, 3)
	await process_frame
	var rule = map.rule
	assert(rule.barriers.size() >= 2)
	var path: Array = rule._shortest_path(rule.floor_data.spawn_cell, rule.floor_data.exit_cell)
	assert(rule.barriers.any(func(c): return c in path))
	gs.current_floor()["wins"] = 1
	change_scene_to_file("res://scenes/exploration/Map.tscn")
	for i in 12:
		await process_frame
	assert(current_scene.rule.barriers.is_empty())

	print("test_places OK")
	quit()
