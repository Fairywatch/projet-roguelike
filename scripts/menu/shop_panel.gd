class_name ShopPanel
extends MenuPanel

# Boutique de meta-progression : des objets passifs payes avec les pieces gagnees en jouant.

func build() -> void:
	add_title("Boutique des songes  -  %d pièces" % GameState.coins)
	var offers := GameState.get_shop_offers()
	for slot in offers.size():
		var id: String = offers[slot]
		if id == "":
			add_button("Vendu", func(): pass).disabled = true
			continue
		var item := Items.find(id)
		var price := GameState.shop_price(id)
		# Une ligne par offre (tier, nom, effet, prix) : avec les ameliorations, le panneau doit tenir a l'ecran.
		var button := add_button("[%s]  %s : %s  -  %d pièces" % [Items.tier(item["id"]), item["name"], item["desc"], price], _buy.bind(slot))
		button.add_theme_color_override("font_color", Items.rarity_color(id))
		button.add_theme_font_size_override("font_size", 15)
		button.custom_minimum_size.y = 20
		button.disabled = GameState.coins < price
	var where := "rejoignent ta nuit en cours" if GameState.run_started else "t'attendront au début de ta prochaine nuit"
	add_note("Les achats %s. Nouvelles offres après chaque réveil." % where)
	# Ameliorations permanentes : gardees pour toujours.
	add_title("Pour toujours")
	for upgrade in GameState.UPGRADES:
		var id: String = upgrade["id"]
		var level := GameState.upgrade_level(id)
		var price := GameState.upgrade_price(id)
		var levels: int = upgrade["prices"].size()
		var rank := "  (%d/%d)" % [level, levels] if levels > 1 else ("  (acquis)" if level > 0 else "")
		# Une ligne par amelioration (nom, effet, prix) : le panneau doit tenir a l'ecran.
		var label := "%s%s : %s  -  %s" % [upgrade["name"], rank, upgrade["desc"], "%d pièces" % price if price >= 0 else "au maximum"]
		var upgrade_button := add_button(label, _buy_upgrade.bind(id))
		upgrade_button.add_theme_font_size_override("font_size", 15)
		upgrade_button.custom_minimum_size.y = 20
		upgrade_button.disabled = price < 0 or GameState.coins < price

func _buy_upgrade(id: String) -> void:
	if GameState.buy_upgrade(id):
		Sound.play("coin")
		rebuild()

func _buy(slot: int) -> void:
	if GameState.buy(slot):
		Sound.play("coin")
		rebuild()
