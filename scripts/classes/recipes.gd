extends Node
class_name RecipeStruct

var type: String
var inputs: Dictionary[ResourceStruct, int]
var outputs: Dictionary[ResourceStruct, int]
var time: float

func _init(json_data):
	var json = JSON.new()
	var result = json.parse(json_data)
	if result == OK:
		var data = json.data
		type = data["type"]
		set_inputs(data["inputs"])
		set_outputs(data["outputs"])
		time = data["time"]
	else:
		push_error("Failed to parse JSON: " + result.error_string)

func set_inputs(input_data: Array):
	for input in range(input_data.size()):
		var key = input_data[input]["name"]
		if ResourceManager.RESOURCES.has(key):
			inputs[ResourceManager.RESOURCES[key]] = int(input_data[input]["value"])
		else:
			push_error("Resource " + key + " not found in ResourceManager.RESOURCES when setting recipe " + self.type + " inputs")

func set_outputs(output_data: Array):
	for output in range(output_data.size()):
		var key = output_data[output]["name"]
		if ResourceManager.RESOURCES.has(key):
			outputs[ResourceManager.RESOURCES[key]] = int(output_data[output]["value"])
		else:
			push_error("Resource " + key + " not found in ResourceManager.RESOURCES when setting recipe " + self.type + " outputs")
