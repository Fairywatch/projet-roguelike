class_name ItemCard

# Fiche d'un objet : icone, pastille de tier (S, A, B, C), nom a la couleur de sa rarete, effet.
# Utilisee par la banniere de ramassage (ItemBanner) et par l'inventaire (InventoryPanel).

static func make(id: String, big: bool = false, suffix: String = "") -> HBoxContainer:
	var item := Items.find(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10 if big else 8)

	var icon := TextureRect.new()
	icon.texture = Items.icon(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * (40 if big else 26)
	row.add_child(icon)
	row.add_child(tier_badge(id, big))

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = item["name"] + suffix
	name_label.add_theme_font_size_override("font_size", 17 if big else 12)
	name_label.add_theme_color_override("font_color", Items.rarity_color(id))
	text.add_child(name_label)
	var desc := Label.new()
	desc.text = "%s  ·  %s" % [item["desc"], Items.RARITY_NAMES[item["rarity"]]]
	desc.add_theme_font_size_override("font_size", 11 if big else 9)
	desc.modulate = Color(1, 1, 1, 0.8)
	text.add_child(desc)
	row.add_child(text)
	return row

# Pastille carree avec la lettre du tier, a sa couleur.
static func tier_badge(id: String, big: bool = false) -> PanelContainer:
	var color := Items.tier_color(id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.22)
	style.border_color = color
	style.set_border_width_all(2 if big else 1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6 if big else 4
	style.content_margin_right = style.content_margin_left
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", style)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var letter := Label.new()
	letter.text = Items.tier(id)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override("font_size", 16 if big else 11)
	letter.add_theme_color_override("font_color", color)
	badge.add_child(letter)
	return badge
