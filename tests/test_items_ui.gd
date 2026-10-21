# Lancer : godot --headless --path . --script res://tests/test_items_ui.gd
# Objets : tier et icone pour chacun, banniere au ramassage, inventaire qui met en pause.
extends SceneTree

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame
	gs.save_path = "user://test_run.save"
	gs.meta_path = "user://test_meta.save"
	gs.new_run(0)

	for item in Items.PASSIVES + Items.ACTIVES:
		assert(item["tier"] in Items.TIER_COLORS, item["id"])
		assert(Items.icon(item["id"]) != null, item["id"])

	# Prendre un objet affiche sa banniere (une seule a la fois), qui s'efface ensuite.
	gs.take_item("plume_de_reve")
	gs.take_item("coeur_de_lune")
	await process_frame
	var banners := get_nodes_in_group("item_banner")
	assert(banners.size() == 1 and banners[0].item_id == "coeur_de_lune")

	# L'inventaire met le jeu en pause et liste l'actif et les passifs ; il se referme.
	gs.take_item("mouchoir_usage")
	change_scene_to_file("res://scenes/exploration/Map.tscn")
	for i in 10:
		await process_frame
	var inventory: Control = current_scene.find_children("*", "InventoryPanel", true, false)[0]
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await process_frame
	await process_frame
	assert(inventory.visible and paused)
	var names := inventory.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert(names.has("Plume de rêve") and names.has("Cœur de lune"))
	assert(names.any(func(n): return n.begins_with("Mouchoir usagé")))
	tab.pressed = false
	Input.parse_input_event(tab)
	await process_frame
	tab.pressed = true
	Input.parse_input_event(tab)
	await process_frame
	assert(not inventory.visible and not paused)

	await create_timer(ItemBanner.HOLD + 1.5).timeout
	assert(get_nodes_in_group("item_banner").is_empty())
	print("test_items_ui OK")
	quit()
