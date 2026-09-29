class_name ShopPanel
extends MenuPanel

# Boutique de meta-progression : des objets passifs payes avec les pieces gagnees en jouant.

func build() -> void:
	add_title("Boutique des songes  -  %d pieces" % GameState.coins)
	var offers := GameState.get_shop_offers()
	for slot in offers.size():
		var id: String = offers[slot]
		if id == "":
			add_button("Vendu", func(): pass).disabled = true
			continue
		var item := Items.find(id)
		var price := GameState.shop_price(id)
		var button := add_button("%s  (%s)  -  %d pieces" % [item["name"], Items.RARITY_NAMES[item["rarity"]], price], _buy.bind(slot))
		button.add_theme_color_override("font_color", Items.rarity_color(id))
		button.disabled = GameState.coins < price
		add_note(item["desc"])
	if GameState.run_started:
		add_note("Les achats rejoignent ta nuit en cours.")
	else:
		add_note("Les achats t'attendront au debut de ta prochaine nuit.")
	add_note("Nouvelles offres apres chaque reveil (mort ou fin de nuit).")

func _buy(slot: int) -> void:
	if GameState.buy(slot):
		Sound.play("coin")
		rebuild()
