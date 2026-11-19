# Lancer : godot --headless --path . --script res://tests/test_updater.gd
extends SceneTree

# Mises a jour : comparaison des versions, et remplacement de l'exe par celui du zip (sur de faux
# fichiers, dans un dossier de test : rien du vrai jeu n'est touche).

const DIR := "user://test_update/"

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _initialize() -> void:
	assert(Updater.is_newer("v0.2", "0.1") and Updater.is_newer("v0.10", "0.9") and Updater.is_newer("1.0.1", "1.0"))
	assert(not Updater.is_newer("v0.1", "0.1") and not Updater.is_newer("0.1", "0.2") and not Updater.is_newer("v1.0", "1.0.0"))
	# Pas de verification hors du jeu exporte (editeur, tests).
	assert(not Updater.should_check())

	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + file)
	var exe := dir + "DreamDive.exe"
	_write(exe, "ancien jeu")
	var zip := dir + "DreamDive-v9.9-windows.zip"
	var packer := ZIPPacker.new()
	packer.open(zip)
	packer.start_file("DreamDive-v9.9-windows/LISEZMOI.txt")
	packer.write_file("lisez-moi".to_utf8_buffer())
	packer.close_file()
	packer.start_file("DreamDive-v9.9-windows/DreamDive.exe")
	packer.write_file("nouveau jeu".to_utf8_buffer())
	packer.close_file()
	packer.close()

	assert(Updater.install(zip, exe) == "")
	assert(_read(exe) == "nouveau jeu" and _read(exe + ".old") == "ancien jeu")
	assert(not FileAccess.file_exists(exe + ".new"))
	# Un zip sans le jeu, ou abime : refuse, et l'exe reste en place.
	var empty := dir + "vide.zip"
	packer = ZIPPacker.new()
	packer.open(empty)
	packer.start_file("autre.txt")
	packer.write_file("rien".to_utf8_buffer())
	packer.close_file()
	packer.close()
	assert(Updater.install(empty, exe) != "" and _read(exe) == "nouveau jeu")
	_write(dir + "abime.zip", "pas un zip")
	assert(Updater.install(dir + "abime.zip", exe) != "" and _read(exe) == "nouveau jeu")

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + file)
	DirAccess.remove_absolute(dir)
	print("test_updater OK")
	quit()
