extends Node

var tick_length: float = 0.05 # Tick length of 50msec, 20tps

var tick_start_time: float
var tick_delta: float

var scheduled_ticks: Dictionary # Not strongly typed because apparently using an enum as type causes it to be an int? 

func _ready() -> void:
	for tick in Global.TICK_CLASS:
		scheduled_ticks[tick] = {}

func schedule_ticks(type: Global.TICK_CLASS, callable: Callable, params: Array) -> bool:
	# Make sure we have the right amount of arguments
	if params.size() != callable.get_argument_count():
		return false
		
	scheduled_ticks[type][callable] = params
	return true

func tick_process() -> void:
	tick_start_time = Time.get_ticks_msec()
	
	@warning_ignore("redundant_await")
	await resource_tick_process(scheduled_ticks[Global.TICK_CLASS.RESOURCES])
	@warning_ignore("redundant_await")
	await generators_tick_process(scheduled_ticks[Global.TICK_CLASS.GENERATORS])
	@warning_ignore("redundant_await")
	await recipe_tick_process(scheduled_ticks[Global.TICK_CLASS.RECIPES])
	@warning_ignore("redundant_await")
	await passive_generators_tick_process()
	
	tick_delta = (Time.get_ticks_msec() - tick_start_time) / 1000.0 # Measure how long the tick took in msec and convert it to sec
	if tick_delta < tick_length: await get_tree().create_timer(tick_length - tick_delta).timeout # Make sure the ticks are always at least tick length msec
	tick_process()

func resource_tick_process(ticks: Dictionary) -> void:
	for callable in ticks.keys():
		callable.call(ticks[callable])
		ticks.erase(callable)

func recipe_tick_process(ticks: Dictionary) -> void:
	# Run recipe unlocks first, to avoid players being unable to run a recipe they just unlocked based on order in which they were scheduled
	for callable in ticks.keys():
		if callable == %Player.unlock_recipe():
			callable.call(ticks[callable])
			ticks.erase(callable)
	
	# Run the recipes themselves
	for callable in ticks.keys():
		callable.call(ticks[callable])
		ticks.erase(callable)

func generators_tick_process(ticks: Dictionary) -> void:
	for callable in ticks.keys():
		callable.call(ticks[callable])
		ticks.erase(callable)

func passive_generators_tick_process() -> void:
	for generator in %Player.player_passive_generators:
		%Player.process_recipe(generator, %Player.player_passive_generators[generator])
