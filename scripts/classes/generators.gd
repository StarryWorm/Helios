extends Node
class_name GeneratorStruct

var type: String
var efficiency: float
var passive: bool
var recipes: Array[RecipeStruct]
var passive_recipe: RecipeStruct

func _init(json_data):
	var json = JSON.new()
	var result = json.parse(json_data)
	if result == OK:
		var data = json.data
		type = data["type"]
		efficiency = data["efficiency"]
		passive = data["passive"]
		set_recipes(data["recipes"])
		if recipes.size() > 0: passive_recipe = recipes[0]
	else:
		push_error("Failed to parse JSON: " + result.error_string)
	pass

func set_recipes(recipe_data: Array):
	if recipe_data.size() == 0: return
	for i in range(recipe_data.size()):
		var recipe = recipe_data[i]
		if ResourceManager.RECIPES.has(recipe):
			recipes.append(ResourceManager.RECIPES[recipe])
		else:
			push_error("Recipe " + recipe + " not found in ResourceManager.RECIPES when setting generator " + self.type)

func set_passive_recipe(recipe: RecipeStruct):
	passive_recipe = recipe
