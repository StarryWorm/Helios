class_name Profiler
extends Node

var init_time: float
var previous_time: float
var previous_operation: String
var previous_time_batch: float
var elapsed_time_batch: Dictionary = {}

func _init():
	return

func init_profiler():
	init_time = Time.get_ticks_usec()
	previous_time = init_time
	previous_operation = "wait"
	elapsed_time_batch.clear()
	print("Initialized Profiler")

func end_profiling():
	var call_time = Time.get_ticks_usec()
	var elapsed_time = (call_time - previous_time)/1000.0
	var total_time = (call_time - init_time)/1000.0
	print("Operation %s took %sms\n End of profiling\n Total Profiler time: %sms" %[previous_operation, elapsed_time, total_time])

func profile_operation(operation_label: String):
	var call_time = Time.get_ticks_usec()
	var elapsed_time = (call_time - previous_time)/1000.0
	print("Operation %s took %sms\nStarting operation %s" %[previous_operation, elapsed_time, operation_label])
	previous_time = call_time
	previous_operation = operation_label

func start_batch_profiling():
	previous_time_batch = Time.get_ticks_usec()

func end_batch_profiling():
	for key in elapsed_time_batch.keys():
		elapsed_time_batch[key] = elapsed_time_batch[key] / 1000.0
	print(elapsed_time_batch)

func profile_operation_batch(operation_label: String):
	var call_time = Time.get_ticks_usec()
	var time_delta = call_time - previous_time_batch
	if elapsed_time_batch.has(operation_label): time_delta += elapsed_time_batch[operation_label]
	elapsed_time_batch[operation_label] = time_delta
	previous_time_batch = call_time

func performance_test():
	init_profiler()
	
	@warning_ignore("unused_variable")
	var test_var = 0
	
	profile_operation("Array Write Test")
	var array: Array = []
	for x in range(1000):
		array.append([])
		for y in range(1000):
			array[x].append([])
			for z in range(20):
				array[x][y].append(z)
	
	profile_operation("Array Read Test")
	for x in range(1000):
		for y in range(1000):
			for z in range(20):
				test_var = array[x][y][z]
	
	
	profile_operation("Nested Array Write Test")
	array.clear()
	for x in range(1000):
		array.append([])
		var temp_array: Array = []
		for y in range(1000):
			temp_array.append([])
			var temp_array_2: Array = []
			for z in range(20):
				temp_array_2.append(z)
			temp_array[y] = temp_array_2
		array[x] = temp_array
	
	profile_operation("Nested Array Read Test")
	for x in range(1000):
		var temp_array = array[x]
		for y in range(1000):
			var temp_array_2 = temp_array[y]
			for z in range(20):
				test_var = temp_array_2[z]
	
	profile_operation("Array Read Test - verify it was done correctly")
	for x in range(1000):
		for y in range(1000):
			for z in range(20):
				test_var = array[x][y][z]
	
	end_profiling()
