extends SceneTree
# Aperçu de scènes/modèles côte à côte. Variables : STACK=1 (superposer), FOCUS=x,y,z, DIST=m.
# usage : xvfb-run -a godot --path . -s res://tests/preview.gd -- sortie.png res://a.glb [res://b.tscn ...]
func _init() -> void:
	run.call_deferred()
func run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var root := Node3D.new(); get_root().add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6,0.6,0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 35, 0); sun.shadow_enabled = true; root.add_child(sun)
	var x := 0.0
	var aabb := AABB()
	var first := true
	for p in args.slice(1):
		var inst: Node3D = load(p).instantiate()
		root.add_child(inst)
		var a := _aabb(inst)
		if OS.get_environment("STACK") == "":
			inst.position.x = x - a.position.x
			x += a.size.x + 0.5
		var a2 := _aabb(inst)
		print(p, " AABB pos=", a2.position, " size=", a2.size)
		aabb = a2 if first else aabb.merge(a2); first = false
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60,60); ground.mesh = pm; root.add_child(ground)
	var cam := Camera3D.new(); root.add_child(cam)
	var c := aabb.get_center(); var r := aabb.size.length()
	var dist := float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else r * 0.8
	if OS.get_environment("FOCUS") != "":
		var f := OS.get_environment("FOCUS").split(",")
		c = Vector3(float(f[0]), float(f[1]), float(f[2]))
	cam.position = c + Vector3(0.35, 0.45, 1).normalized() * dist
	cam.look_at(c)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
func _aabb(n: Node) -> AABB:
	var res := AABB(); var f := true
	for m in n.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = m.global_transform * m.get_aabb()
		res = b if f else res.merge(b); f = false
	return res
