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
	for child in node. 	get_children():
		makeLocal(child)
	




func _run():
	err.text = ""
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
	recursively_delete_dir_absolute("res://MapPck")
	DirAccess.open("res://").make_dir("MapPck")
	DirAccess.open("res://").make_dir("MapPck/scenes")
	var sp =  "res://MapPck/scenes" + current_scene.scene_file_path.left(len(current_scene.scene_file_path)-5).right(-5) + ".tscn"
	get_editor_interface().save_scene_as(sp)
	var idx = get_editor_interface().get_open_scenes().find(sp)
	print(idx)
	# ok, now we need to turn this scene into a glb
	var ccurrent_scene = get_editor_interface().get_edited_scene_root()
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	doc.append_from_scene(ccurrent_scene, state)
	var glbpath = "res://MapPck" + oldpath.left(len(oldpath)-5).right(-5) + ".glb"
	print(glbpath)
	FileAccess.open("res://MapPck/.gdignore", FileAccess.WRITE)
	recursively_delete_dir_absolute("res://MapPck/scenes")
	doc.write_to_filesystem(state, glbpath) #write glb
	OS.shell_open(ProjectSettings.globalize_path("res://MapPck/"))
	get_editor_interface().get_open_scenes().remove_at(idx)
	get_editor_interface().open_scene_from_path(oldpath)
	get_editor_interface().get_file_system_dock().navigate_to_path("/") # Reload FSDock maybe idk
	







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
