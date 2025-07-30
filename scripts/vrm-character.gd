extends CharacterBody3D

@onready var animation_tree: AnimationTree = $AnimationTree

@export_category("Character")
@export var character_name: String = "Char_Name"

func _ready():
	#Dialogic.signal_event.connect(_on_dialogic_dictionary_signal)
	Dialogic.signal_event.connect(_on_dialogic_string_signal)
	
func set_animation_condition(condition_name:String, value: bool):
	
	# Construct the parameter path
	var parameter_path ="parameters/conditions/" + condition_name
	animation_tree.set(parameter_path, value)
	
	# Check if the parameter exissts
	#if animation_tree.has_node(parameter_path):
		##Set the condition value
		#animation_tree[parameter_path] = value
	#else:
		#printerr("Error: AnimationTree does not have a condition parameter named ", condition_name)
		
func _on_dialogic_dictionary_signal(argument: Dictionary):
	print("A Dictionary signal was fired from Dialogic: ", argument)
	if argument["character"] != character_name:
		pass
	print("Animation signal from Dialogic for ", argument["character"])
	if argument["animation"] == null || argument["value"] == null:
		pass
	set_animation_condition(argument["animation"], argument["value"])
	
func _on_dialogic_string_signal(argument: String):
	print("A String signal was fired via Dialogic: ", argument)
	match argument:
		"Dance":
			# Set the Dance condition to false
			set_animation_condition("Dance", true)
			set_animation_condition("Idle", false)
		"Idle":
			# Set Idle condition to true
			set_animation_condition("Dance", false)
			set_animation_condition("Idle", true)
