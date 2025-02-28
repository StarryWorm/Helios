extends Node
class_name ResourceStruct

var type: String
var value: float
var icon: Sprite2D

func _init(json_data):
	var json = JSON.new()
	var result = json.parse(json_data)
	if result == OK:
		var data = json.data
		type = data["type"]
		value = data["value"]
		#set_icon(data["icon"])
	else:
		push_error("Failed to parse JSON: " + result.error_string)

func set_icon(filename: String):
	if icon != null: icon = null
	icon = Sprite2D.new()
	var image = Image.load_from_file("res://textures/resources/" + filename)
	var texture = ImageTexture.create_from_image(image)
	icon.texture = texture

func set_value(val: float):
	value = val

func get_value() -> float:
	return value
