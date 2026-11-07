@tool
extends EditorPlugin
## Outil de dev, lancé par tools/resave_with_editor.sh : attend la fin des imports, réenregistre
## chaque scène de res://scenes avec l'éditeur (uid, unique_id… au format exact de l'éditeur),
## laisse l'éditeur finir ses réimports (détection 3D des textures), puis quitte.

const SCENES_DIR := "res://scenes"
const SETTLE_TIME := 4.0


func _enter_tree() -> void:
	_run.call_deferred()


func _run() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	await get_tree().create_timer(SETTLE_TIME).timeout
	while filesystem.is_scanning():
		await get_tree().process_frame
	for path in _scene_paths():
		EditorInterface.open_scene_from_path(path)
		await get_tree().process_frame
		EditorInterface.mark_scene_as_unsaved()
		EditorInterface.save_scene()
		print("[resave] ", path)
	# Les textures utilisées en 3D sont réimportées (compression GPU) : on laisse finir.
	await get_tree().create_timer(SETTLE_TIME).timeout
	while filesystem.is_scanning():
		await get_tree().process_frame
	get_tree().quit()


func _scene_paths() -> Array[String]:
	var paths: Array[String] = []
	var dirs: Array[String] = [SCENES_DIR]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".tscn"):
				paths.append(dir + "/" + file)
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir + "/" + sub)
	paths.sort()
	return paths
