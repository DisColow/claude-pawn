extends SceneTree
# Charge et instancie toutes les scènes de res://scenes (détecte ressources manquantes / erreurs de script).
# usage : godot --headless --path . -s res://tests/load_all.gd
func _init() -> void:
	run.call_deferred()
func run() -> void:
	var paths: Array[String] = []
	var dirs := ["res://scenes"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".tscn"): paths.append(d + "/" + f)
		for sd in DirAccess.get_directories_at(d): dirs.append(d + "/" + sd)
	for p in paths:
		var inst: Node = load(p).instantiate()
		print("OK ", p, " -> ", inst.get_class())
		inst.free()
	quit()
