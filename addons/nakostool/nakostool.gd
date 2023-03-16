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
	
var ascii = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
func get_prefix(node: Node, scene: Node):
	var rand = ""
	for i in range(5):
		rand += ascii[randi_range(0, len(ascii)-1)]
	var sname = scene.scene_file_path.left(-5).split("/")
	sname = sname[len(sname)-1]
	return "map-" + sname + "-" + node.name + "-" + rand + "-"


func makeLocal(node):
	var current_scene = get_editor_interface().get_edited_scene_root()
	if node.scene_file_path != "" or node.owner != current_scene:
		node.scene_file_path  = ""
		node.owner = current_scene
	for child in node. 	get_children():
		makeLocal(child)
	

var covered_obj = []
var resc = 0

func scanRes(node: Object, prefix):
	if node in covered_obj:
		return
	covered_obj.append(node)
	var props = node.get_property_list()
	for p in props:
		if p["type"] == 24:
			var value = node.get(p["name"])
			if value == null or not value is Resource:
				continue
			scanRes(value, prefix)
			var nres: Resource = value.duplicate()
			resc += 1
			
			if "::" in value.resource_path and value.resource_path != "":
				pass
			else:
				nres.take_over_path("res://MapPck/Assets/" + prefix + str(resc) + ".tres")
				ResourceSaver.save(nres)
				print("nv  ", nres.resource_path, "   ov  ",value.resource_path)
			node.set(p["name"], nres)

func doNode(node, scene):
	scanRes(node, get_prefix(node, scene))
	for ch in node.get_children():
		doNode(ch, scene)

func _run():
	var current_scene = get_editor_interface().get_edited_scene_root()
	var oldpath = current_scene.scene_file_path
	for child in current_scene.get_children():
		makeLocal(child)
	recursively_delete_dir_absolute("res://MapPck")
	DirAccess.open("res://").make_dir("MapPck")
	DirAccess.open("res://").make_dir("MapPck/Assets")
	get_editor_interface().save_scene_as("res://MapPck" + current_scene.scene_file_path.left(len(current_scene.scene_file_path)-5).right(-5) + ".tscn")
	get_editor_interface().reload_scene_from_path(current_scene.scene_file_path)
	covered_obj = []
	resc = 0
	# bring all resources into assets
	doNode(get_editor_interface().get_edited_scene_root(), get_editor_interface().get_edited_scene_root())
	get_editor_interface().save_scene()
	get_editor_interface().get_file_system_dock().navigate_to_path("/") # Reload FSDock maybe idk
	get_editor_interface().open_scene_from_path(oldpath)


var btm

func _enter_tree():
	var ctrl = Control.new()
	ctrl.custom_minimum_size.y = 100
	var btn = Button.new()
	btn.text = "Build"
	btn.pressed.connect(_run)
	ctrl.add_child(btn)
	btm = add_control_to_bottom_panel(ctrl, "CreatorTools")


func _exit_tree():
	btm.queue_free()


func _get_plugin_name():
	return "Creator Tools"


func _get_plugin_icon():
	# Must return some kind of Texture for the icon.
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")
