extends Object


class_name JavaScriptGenerator

var code_builder := ""

func add_declare(name):
	code_builder += "var " + str(name) + " = "

func add_array():
	code_builder += "["

func add_elem(e):
	code_builder += e + ", "

func end_array():
	code_builder += "]"

func end():
	code_builder += ";\n"

func add_call(method):
	code_builder += method + "("

func next_param():
	code_builder += ", "

func end_call():
	code_builder += ")"

func add_comment(comment):
	code_builder += "// " + str(comment) + "\n"

func add_new_line():
	code_builder += "\n"

func append(code):
	code_builder += str(code)

func generate_lambda() -> String:
	var code := code_builder
	return "() => {" + code + "}"

func get_code() -> String:
	return code_builder
