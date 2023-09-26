@tool
extends EditorPlugin


func _ready():
	randomize()

func recursively_delete_dir_absolute(folder: String) -> bool:
	# Delete folder if it exists
	if DirAccess.dir_exists_absolute(folder):
		# Open folder
		var access := DirAccess.open(folder)
		# Delete all files within the folder
		access.list_dir_begin() 
		var file_name = access.get_next()
		while file_name != "":
			if not access.current_is_dir():
				access.remove(file_name)
			else:
				# If it contains more folders, first delete that folder recursively
				recursively_delete_dir_absolute(folder + "/" + file_name)
				
			file_name = access.get_next()
		# Delete the now empty folder
		if DirAccess.remove_absolute(folder) != OK:
			return false
		return true
	return false



func makeLocal(node):
	var current_scene = get_editor_interface().get_edited_scene_root()
	if node.scene_file_path != "" or node.owner != current_scene:
		node.scene_file_path  = ""
		node.owner = current_scene
	for child in node.get_children():
		makeLocal(child)
	

func propagateGroups(node: Node, groups):
	var ngroups = groups + node.get_groups()
	for g in groups:
		node.add_to_group(g, true)
	for child in node.get_children():
		propagateGroups(child, ngroups)



func generateCollision(node: Node):
	if !node.is_in_group("nocollide"):
		if node is MeshInstance3D:
			node.create_trimesh_collision() # generate collision. 
	for child in node.get_children():
		generateCollision(child)

func jsgWriteVec3PackedInArray(jsg: JavaScriptGenerator, vec: Vector3):
	for i in [vec.x, vec.y, vec.z]:
		jsg.add_elem(str(i))

func jsgWriteTransform(jsg: JavaScriptGenerator, trans: Transform3D):
	jsg.add_array()
	for vec in [trans.basis.x, trans.basis.y, trans.basis.z]:
		jsgWriteVec3PackedInArray(jsg, vec)
	jsgWriteVec3PackedInArray(jsg, trans.origin)
	jsg.end_array()

func jsgWriteVec3(jsg: JavaScriptGenerator, vec: Vector3):
	jsg.add_array()
	jsgWriteVec3PackedInArray(jsg, vec)
	jsg.end_array()

func jsgWriteVec3Array(jsg: JavaScriptGenerator, arr: PackedVector3Array):
	jsg.add_array()
	for vec in arr:
		jsgWriteVec3(jsg, vec)
		jsg.add_elem("")
	jsg.end_array()

func generateJSCollision(node: Node, jsg: JavaScriptGenerator):
	if node is CollisionShape3D:
		var sh = node.shape
		if sh is BoxShape3D:
			jsg.add_call("MapBuilder.create_box_col")
			jsgWriteTransform(jsg, node.global_transform)
			jsg.next_param()
			jsgWriteVec3(jsg, sh.size)
			jsg.end_call()
			jsg.end()
		if sh is ConcavePolygonShape3D:
			jsg.add_call("MapBuilder.create_concave_col")
			jsgWriteTransform(jsg, node.global_transform)
			jsg.next_param()
			jsgWriteVec3Array(jsg, sh.get_faces())
			jsg.end_call()
			jsg.end()
		if sh is CylinderShape3D or sh is CapsuleShape3D:
			if sh is CylinderShape3D:
				jsg.add_call("MapBuilder.create_cylinder_col")
			else:
				jsg.add_call("MapBuilder.create_capsule_col")
			jsgWriteTransform(jsg, node.global_transform)
			jsg.next_param()
			jsg.append(str(sh.height))
			jsg.next_param()
			jsg.append(str(sh.radius))
			jsg.end_call()
			jsg.end()
		if sh is SphereShape3D:
			jsg.add_call("MapBuilder.create_sphere_col")
			jsgWriteTransform(jsg, node.global_transform)
			jsg.next_param()
			jsg.append(str(sh.radius))
			jsg.end_call()
			jsg.end()
		if sh is WorldBoundaryShape3D:
			jsg.add_call("MapBuilder.create_boundary_col")
			jsgWriteTransform(jsg, node.global_transform)
			jsg.next_param()
			jsg.add_array()
			for i in [sh.plane.x, sh.plane.y, sh.plane.z, sh.plane.d]:
				jsg.add_elem(i)
			jsg.end_array()
			jsg.end_call()
			jsg.end()
	for child in node.get_children():
		generateJSCollision(child, jsg)

func generateJSEnvironment(node: Node, jsg: JavaScriptGenerator):
	jsg.add_call("MapBuilder.create_environment")
	jsg.end_call()
	jsg.end()
	var we: WorldEnvironment = node.get_node("WorldEnvironment")
	if is_instance_valid(we):
		var env: Environment = we.environment
		assert(env.background_mode == Environment.BG_SKY)
		var sky: Sky = env.sky
		var mat = sky.sky_material
		if not mat is ShaderMaterial:
			var plugs = get_editor_interface().find_resource_conversion_plugin(mat)
			var plug
			print("Mat: ", mat)
			for p in plugs:
				if p.converts_to() == "ShaderMaterial":
					plug = p
					break
			if plug == null:
				push_warning("Error: Could not convert sky material")
				return
			mat = plug.convert(mat)
			var shad: Shader = mat.shader
			var code = shad.code
			jsg.add_call("MapBuilder.set_sky_shader")
			jsg.add_call("Nakos.load_resource")
			jsg.append('"sky_shader.glsl"')
			jsg.end_call()
			jsg.end_call()
			jsg.end()
			var fa = FileAccess.open("res://MapPck/sky_shader.glsl", FileAccess.WRITE)
			fa.store_string(code)
			fa.close()
		else:
			push_warning("Error: Could not convert sky material")
	else:
		push_warning("Error: No worldenvironment provided. May use default")

func _run():
	err.text = "Expanding subscenes..."
	var current_scene = get_editor_interface().get_edited_scene_root()
	if (!current_scene) or (current_scene.scene_file_path == ""):
		err.text = "Open a scene"
		return
	if current_scene.scene_file_path.contains("MapPck"):
		err.text = "Cannot build an exported scene"
		return
	if !current_scene.has_meta("MapInfo"):
		err.text = "MapInfo required. Press help and follow guide."
		return
	if current_scene.get_meta("MapInfo").level_ver == "CHANGEME":
		err.text = "Setup MapInfo. Press help and follow guide."
		return
	
	var oldpath = current_scene.scene_file_path
	for child in current_scene.get_children():
		makeLocal(child)

	err.text = "Propagating groups..."
	# after expanding all packed scenes, lets make groups propagate to children of a node
	propagateGroups(get_editor_interface().get_edited_scene_root(), [])
	
	err.text = "Generating collision on MeshInstances..."
	# after ensuring groups are propagated, we can safely generate collision and staticbodies
	generateCollision(get_editor_interface().get_edited_scene_root())
	
	err.text = "Generating JS collision code"
	var jsg = JavaScriptGenerator.new()
	jsg.add_comment("MACHINE GENERATED CODE. DO NOT EDIT")
	jsg.add_call("nakos.RequestModuleInRuntime")
	jsg.append('"MapBuilder"')
	jsg.end_call()
	jsg.end()
	jsg.add_new_line()
	generateJSCollision(get_editor_interface().get_edited_scene_root(), jsg)
	
	
	err.text = "Saving scene..."
	recursively_delete_dir_absolute("res://MapPck")
	DirAccess.open("res://").make_dir("MapPck")
	DirAccess.open("res://").make_dir("MapPck/scenes")

	
	
	generateJSEnvironment(get_editor_interface().get_edited_scene_root(), jsg)

	
	err.text = "Exporting gltf..."
	# ok, now we need to turn this scene into a glb
	var ccurrent_scene = get_editor_interface().get_edited_scene_root()
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	doc.append_from_scene(ccurrent_scene, state)
	var mapname = oldpath.left(len(oldpath)-5).right(-5)
	print(mapname)
	var glbpath = "res://MapPck" + mapname + ".glb"
	print(glbpath)
	FileAccess.open("res://MapPck/.gdignore", FileAccess.WRITE).close()
	doc.write_to_filesystem(state, glbpath) #write glb
	get_editor_interface().reload_scene_from_path(oldpath)
	ccurrent_scene = get_editor_interface().get_edited_scene_root()
	var mapdata: MapInfo = ccurrent_scene.get_meta("MapInfo")
	# ok, now we need to make a metadata file for the map
	var metadata = {
		# global section
		"meta_ver": "1.0",
		"content_type": "map",
		
		"map": {
			"name": mapdata.level_name,
			"version": mapdata.level_ver,
			"tags": mapdata.level_tags,
			"js": mapname + ".load.js"
		}
	}
	
	var jmd = FileAccess.open("res://MapPck" + mapname + ".load.js", FileAccess.WRITE)
	jmd.store_string(jsg.get_code())
	jmd.close()
	
	var md = FileAccess.open("res://MapPck" + mapname + ".meta", FileAccess.WRITE)
	GDToml.write_toml_file(md, metadata)
	md.close()
	
	err.text = "Compressing"
	# zip it
	var zp = ZIPPacker.new()
	zp.open("res://MapPck/" + mapname + ".zip")
	# for each file
	for i in [glbpath, "res://MapPck" + mapname + ".meta", "res://MapPck" + mapname + ".load.js"]:
		zp.start_file(i.get_file())
		zp.write_file(FileAccess.get_file_as_bytes(i))
		zp.close_file()
	zp.close()
	
	
	
	get_editor_interface().get_file_system_dock().navigate_to_path("/") # Reload FSDock maybe idk
	OS.shell_open(ProjectSettings.globalize_path("res://MapPck/"))

	err.text = "Done"





var btm
var le3
var err 
func _enter_tree():
	var ctrl = Control.new()
	ctrl.custom_minimum_size.y = 100
	
	var btn = Button.new()
	btn.text = "Build map"
	btn.pressed.connect(_run)
	ctrl.add_child(btn)
	
	err = Label.new()
	err.text = "status text"
	err.position.x = 100
	ctrl.add_child(err)
	
	var btn2 = Button.new()
	btn2.text = "Help"
	btn2.position.y = 30
	btn2.pressed.connect(help)
	ctrl.add_child(btn2)
	
	var btn3 = Button.new()
	btn3.text = "New level"
	btn3.position.y = 60
	btn3.pressed.connect(new)
	ctrl.add_child(btn3)
	
	le3 = LineEdit.new()
	le3.placeholder_text = "level name"
	le3.size.x = 400
	le3.position.y = 60
	le3.position.x = 100
	ctrl.add_child(le3)
	
	
	btm = add_control_to_bottom_panel(ctrl, "CreatorTools")

func help():
	OS.shell_open("https://google.com")

func new():
	var name = le3.text + ".tscn"
	var scn = preload("res://addons/nakostool/template.tscn").instantiate()
	scn.scene_file_path = "res://" + name
	scn.set_meta("MapInfo", scn.get_meta("MapInfo").duplicate())
	var ps = PackedScene.new()
	ps.pack(scn)
	ResourceSaver.save(ps, scn.scene_file_path)
	get_editor_interface().open_scene_from_path(scn.scene_file_path)

func _exit_tree():
	btm.queue_free()

func _get_plugin_name():
	return "Creator Tools"

func _get_plugin_icon():
	# Must return some kind of Texture for the icon.
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")
