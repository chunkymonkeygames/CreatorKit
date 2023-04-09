extends Node
# TOML Parser in GDScript using FileAccess
# Requires Godot 4

class_name GDToml



# Writes a TOML dictionary to a file using a given FileAccess object
static func write_toml_file(file: FileAccess, toml_data: Dictionary):
	for key in toml_data.keys():
		var value = toml_data[key]

		# Write section header
		if value is Dictionary:
			_write_toml_section(file, key, value)
			continue

		# Write key-value pair
		file.store_string(key + " = " + _format_toml_value(value) + "\n")

# Helper function to write a TOML section to a file
static func _write_toml_section(file: FileAccess, section_name: String, section_data: Dictionary):
	file.store_string("[" + section_name + "]\n")
	for key in section_data.keys():
		var value = section_data[key]
		file.store_string(key + " = " + _format_toml_value(value) + "\n")

# Helper function to format a TOML key-value pair
static func _format_toml_value(value: Variant) -> String:
	var value_str = ""

	if value is bool:
		value_str = str(value)
	elif value is int or value is float:
		value_str = str(value)
	elif value is String:
		value_str = '"' + value + '"'
	elif value is Array:
		value_str = _format_toml_array(value)

	return value_str

# Helper function to format a TOML array
static func _format_toml_array(array: Array) -> String:
	var inner = ""
	var first = true
	for val in array:
		if !first:
			inner += ", "
		first = false
		inner += _format_toml_value(val)
	var arr_str = "[" + inner + "]"
	return arr_str
