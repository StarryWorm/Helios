extends Node

var player_resources: Dictionary[ResourceStruct, int]
var player_recipes: Array[RecipeStruct]
var player_generators: Dictionary[GeneratorStruct, int]
var player_passive_generators: Dictionary[GeneratorStruct, int]

# Helper function to give the player resources
func give_resource(resource: ResourceStruct, amount: int) -> bool:
	# Make sure the resource is instantiated
	if ResourceManager.RESOURCES.find_key(resource) == null: 
		push_error("Could not find ", resource.type, " in ResourceManager.RESOURCES")
		return false
	
	# Add the resource to the player if it is encountered for the first time
	if not player_resources.has(resource): player_resources[resource] = 0
	
	# Check that the player has enough of the amount in case its negative. Positive values of amount will return a negative number, which is always less than 0, so always passes check
	if player_resources[resource] < -1 * amount: return false
	
	# Give the amount to the player
	player_resources[resource] += amount
	
	return true

# Helper function to unlock recipes for the player
func unlock_recipe(recipe: RecipeStruct) -> void:
	# Makes sure the recipe is instantiated
	if ResourceManager.RECIPES.find_key(recipe) == null: 
		push_error("Could not find ", recipe.type, " in ResourceManager.RECIPES")
	
	# Unlock the recipe if it isn't unlocked yet
	if not player_recipes.has(recipe):
		player_recipes.append(recipe)

# Helper function to give the player generators, returns success as boolean
func give_generators(generator: GeneratorStruct, amount: int) -> bool:
	# Make sure the resource is instantiated
	if ResourceManager.GENERATORS.find_key(generator) == null: 
		push_error("Could not find ", generator.type, " in ResourceManager.GENERATORS")
		return false
	
	var generators = player_generators
	if generator.passive: generators = player_passive_generators
	
	# Add the generator to the player if it is encountered for the first time
	if not generators.has(generator): generators[generator] = 0
	
	# Check that the player has enough of the amount in case its negative. Positive values of amount will return a negative number, which is always less than 0, so always passes check
	if generators[generator] < -1 * amount: return false
	
		# Give the amount to the player
	generators[generator] += amount
	
	return true

func process_recipe(generator: GeneratorStruct, recipe: RecipeStruct, amount: int) -> bool:
	# Exit immediately if amount is 0 - useful for passive generators who generate process_recipe calls every frame but may not be available every frame
	if amount == 0: return true
	
	# Make sure the generator is instantiated, and has the recipe
	if ResourceManager.GENERATORS.find_key(generator) == null: 
		push_error("Could not find ", generator.type, " in ResourceManager.GENERATORS")
		return false
	if ResourceManager.RECIPES.find_key(recipe) == null: 
		push_error("Could not find ", recipe.type, " in ResourceManager.RECIPES")
		return false
	if not generator.recipes.has(recipe):
		push_error("Generator ", generator.type, " does not have recipe ", recipe.type)
		return false
	
	# Make sure the player has at least enough such generators, and has unlocked the recipe
	if not player_generators.has(generator):
		print("PLayer does not have any generator ", generator.type)
		return false
	if not player_recipes.has(recipe):
		print("Player has not unlocked recipe ", recipe.type)
		return false
	if player_generators[generator] < amount:
		print("Player does not have enough generators ", generator, ". Needed: ", amount, ". Has: ", player_generators[generator])
		return false
	
	# Make sure the resources are instantiated and the player has adequate resources
	for resource in recipe.inputs.keys():
		if ResourceManager.RESOURCES.find_key(resource) == null:
			push_error("Could not find ", resource.type, " in ResourceManager.RESOURCES")
			return false
		
		var recipe_resource_amount = recipe.inputs[resource] * amount
		if not player_resources.has(resource):
			print("Player does not have resource ", resource.type)
			return false
		if player_resources[resource] < recipe_resource_amount:
			print("Player does not have enough ", resource.type, ". Needed: ", recipe_resource_amount, ". Has: ", player_resources[resource])
			return false
	
	# Spend the resources from the player's inventory
	for resource in recipe.inputs.keys():
		var recipe_resource_amount = recipe.inputs[resource] * amount
		player_resources[resource] -= recipe_resource_amount
	
	# Temporarily reduce the player's available generators of the type
	player_generators[generator] -= amount
	
	# Run the recipe
	var recipe_time = recipe.time / generator.efficiency
	print("Running recipe for ", recipe_time, " seconds")
	await get_tree().create_timer(recipe_time).timeout
	
	# Return the generators to the player
	player_generators[generator] += amount
	
	# Get recipe outputs and give them to player
	for resource in recipe.outputs.keys():
		var recipe_resource_amount = recipe.outputs[resource] * amount
		give_resource(resource, recipe_resource_amount)
	
	print(player_resources)
	return true
