class_name UpdatePanel
extends MenuPanel

# Nouvelle version disponible (Updater) : ce qui change, puis "Mettre a jour" (telecharge, remplace
# le jeu et redemarre) ou Retour (plus tard). En cas d'echec, un bouton ouvre la page de la version.

const NOTES_MAX := 420  # caracteres de notes de version affiches

var updater: Updater
var state := "ask"  # "ask", "downloading", "failed"
var status := ""

func _ready() -> void:
	updater.progress.connect(_on_progress)
	updater.failed.connect(_on_failed)
	super._ready()

func build() -> void:
	var release := updater.release
	add_title("Nouvelle version !")
	add_note("La version %s est sortie (tu as la %s)." % [release["version"], Updater.current_version()], Color(1, 0.9, 0.55))
	var notes: String = release["notes"].strip_edges()
	if notes != "":
		add_note(notes if notes.length() <= NOTES_MAX else notes.left(NOTES_MAX) + "…")
	match state:
		"ask":
			add_button("Mettre à jour  (%d Mo)" % ceili(release["zip_size"] / 1048576.0), _start)
			add_note("Le jeu se télécharge, se remplace puis redémarre. Tes sauvegardes sont conservées.")
		"downloading":
			add_note(status if status != "" else "Téléchargement…", Color(0.75, 0.85, 1))
		"failed":
			add_note(status, Color(1, 0.5, 0.5))
			add_button("Ouvrir la page de téléchargement", func(): OS.shell_open(release["page"]))

func _start() -> void:
	state = "downloading"
	status = ""
	rebuild()
	updater.download()

func _on_progress(done: int, total: int) -> void:
	var text := "Téléchargement… %d Mo" % (done / 1048576)
	if total > 0:
		text += " / %d Mo  (%d %%)" % [total / 1048576, 100 * done / total]
	# Mise a jour du texte sans tout reconstruire (le focus resterait sur Retour).
	for label in box.get_children():
		if label is Label and label.text.begins_with("Téléchargement"):
			label.text = text
	status = text

func _on_failed(reason: String) -> void:
	state = "failed"
	status = reason + " Tu peux télécharger la nouvelle version à la main."
	rebuild()

func close() -> void:
	if state == "downloading":
		updater.cancel()
	super.close()
