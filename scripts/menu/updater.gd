class_name Updater
extends Node

# Mises a jour automatiques (jeu exporte pour Windows seulement) : au lancement, demande a GitHub
# la derniere version publiee (tools/export_game.py --publish cree la release "v<version>" avec le
# zip). Si elle est plus recente que application/config/version, UpdatePanel la propose ; le zip
# est alors telecharge, l'exe en cours renomme en .old (Windows le permet meme pendant qu'il
# tourne), le nouvel exe pose a sa place, et le jeu redemarre. Le .old est efface au lancement
# suivant. Les sauvegardes (user://) ne bougent pas.

signal found(release: Dictionary)  # {version, notes, page, zip_url, zip_size}
signal progress(done: int, total: int)
signal failed(reason: String)

const API := "https://api.github.com/repos/Fairywatch/projet-roguelike/releases/latest"
const API_OVERRIDE_ENV := "DREAMDIVE_UPDATE_API"  # pour tester avec un faux serveur
const ZIP_SUFFIX := "-windows.zip"
const EXE_NAME := "DreamDive.exe"
const DOWNLOAD_PATH := "user://update/latest.zip"
const TIMEOUT := 8.0  # verification : on ne fait pas attendre le joueur

static var checked := false  # une seule verification par lancement

var http := HTTPRequest.new()
var release := {}

func _ready() -> void:
	http.use_threads = true
	add_child(http)
	set_process(false)  # la progression ne sert que pendant un telechargement

# Seulement dans le jeu exporte pour Windows (pas dans l'editeur), une fois, si le joueur le veut.
static func should_check() -> bool:
	return not checked and OS.has_feature("template") and OS.get_name() == "Windows" and Settings.enabled("check_updates")

static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))

# "v0.10.2" > "0.9" : compare nombre par nombre.
static func is_newer(candidate: String, current: String) -> bool:
	var a := _numbers(candidate)
	var b := _numbers(current)
	for i in maxi(a.size(), b.size()):
		var x: int = a[i] if i < a.size() else 0
		var y: int = b[i] if i < b.size() else 0
		if x != y:
			return x > y
	return false

static func _numbers(version: String) -> Array:
	return Array(version.trim_prefix("v").split(".")).map(func(part: String): return part.to_int())

# L'exe d'avant une mise a jour, s'il reste : efface (au lancement suivant, il ne tourne plus).
static func clean_old() -> void:
	var old := OS.get_executable_path() + ".old"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)

func check() -> void:
	checked = true
	clean_old()
	var url := OS.get_environment(API_OVERRIDE_ENV)
	http.timeout = TIMEOUT
	http.request_completed.connect(_on_checked, CONNECT_ONE_SHOT)
	var headers := ["User-Agent: DreamDive-updater", "Accept: application/vnd.github+json"]
	if http.request(url if url != "" else API, headers) != OK:
		http.request_completed.disconnect(_on_checked)

func _on_checked(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # pas d'internet, pas de release : on joue, tout simplement
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not is_newer(str(data.get("tag_name", "")), current_version()):
		return
	for asset in data.get("assets", []):
		if str(asset.get("name", "")).ends_with(ZIP_SUFFIX):
			release = {
				"version": str(data["tag_name"]).trim_prefix("v"),
				"notes": str(data.get("body", "")),
				"page": str(data.get("html_url", "")),
				"zip_url": str(asset["browser_download_url"]),
				"zip_size": int(asset.get("size", 0)),
			}
			found.emit(release)
			return

func download() -> void:
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_PATH.get_base_dir())
	http.timeout = 0.0
	http.download_file = DOWNLOAD_PATH
	http.request_completed.connect(_on_downloaded, CONNECT_ONE_SHOT)
	if http.request(release["zip_url"], ["User-Agent: DreamDive-updater"]) != OK:
		http.request_completed.disconnect(_on_downloaded)
		failed.emit("Téléchargement impossible.")
		return
	set_process(true)

func cancel() -> void:
	http.cancel_request()
	set_process(false)

func _process(_delta: float) -> void:
	if http.get_http_client_status() == HTTPClient.STATUS_BODY:
		var total := http.get_body_size()
		progress.emit(http.get_downloaded_bytes(), total if total > 0 else int(release.get("zip_size", 0)))

func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	set_process(false)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		failed.emit("Le téléchargement a échoué (erreur %d / %d)." % [result, code])
		return
	var error := install(ProjectSettings.globalize_path(DOWNLOAD_PATH), OS.get_executable_path())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DOWNLOAD_PATH))
	if error != "":
		failed.emit(error)
		return
	OS.create_process(OS.get_executable_path(), [])
	get_tree().quit()

# Remplace l'exe par celui du zip. Renvoie "" si tout va bien, sinon la raison.
static func install(zip_path: String, exe: String) -> String:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return "Le fichier téléchargé est abîmé."
	var entry := ""
	for file in reader.get_files():
		if file.get_file() == EXE_NAME:
			entry = file
	var bytes := reader.read_file(entry) if entry != "" else PackedByteArray()
	reader.close()
	if bytes.is_empty():
		return "La mise à jour ne contient pas le jeu."
	var fresh := exe + ".new"
	var file := FileAccess.open(fresh, FileAccess.WRITE)
	if file == null:
		return "Impossible d'écrire dans le dossier du jeu (%s)." % exe.get_base_dir()
	file.store_buffer(bytes)
	file.close()
	var old := exe + ".old"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)
	if DirAccess.rename_absolute(exe, old) != OK:
		DirAccess.remove_absolute(fresh)
		return "Impossible de remplacer le jeu."
	if DirAccess.rename_absolute(fresh, exe) != OK:
		DirAccess.rename_absolute(old, exe)  # on remet l'ancien
		return "Impossible de remplacer le jeu."
	return ""
