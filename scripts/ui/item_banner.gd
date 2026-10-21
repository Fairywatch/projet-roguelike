class_name ItemBanner
extends CanvasLayer

# Banniere facon Isaac quand on ramasse un objet : sa fiche descend en haut de l'ecran, reste un
# moment puis s'efface. Posee a la racine de l'arbre : elle survit au changement de scene (on
# quitte l'arene juste apres avoir pris le butin).

const HOLD := 2.6
const TOP := 62.0  # sous l'interface du haut (coeurs, etage, objets)

var item_id := ""
var panel := PanelContainer.new()

static func show_item(id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for old in tree.get_nodes_in_group("item_banner"):
		old.queue_free()
	var banner := ItemBanner.new()
	banner.item_id = id
	tree.root.add_child(banner)

func _ready() -> void:
	add_to_group("item_banner")
	layer = 50
	panel.add_child(ItemCard.make(item_id, true))
	panel.modulate.a = 0.0
	add_child(panel)
	await get_tree().process_frame  # taille connue une fois la fiche construite
	var width := get_viewport().get_visible_rect().size.x
	panel.reset_size()
	panel.position = Vector2((width - panel.size.x) / 2.0, TOP - 16.0)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(panel, "position:y", TOP, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
