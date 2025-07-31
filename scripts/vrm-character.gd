extends CharacterBody3D

@export_category("Character")
@export var character_name: String = "Char_Name"
@export var initial_anim: String = "Idle"

@onready var animation_tree: AnimationTree = $AnimationTree

func _ready():
	Dialogic.signal_event.connect(_on_dialogic_dictionary_signal)
	
func set_animation_condition(condition_name:String, value: bool):
	# Cancel previous anim
	if initial_anim != "":
		var path ="parameters/conditions/" + initial_anim
		animation_tree.set(path, false)
		
	# Construct the parameter path
	var parameter_path ="parameters/conditions/" + condition_name
	
	# Check if the parameter exists
	# if animation_tree.has_node(parameter_path):
	# 	print("Successful found condition parameter in AnimationTree called: ", condition_name)
		#Set the condition value
		#animation_tree[parameter_path] = value
	# else:
	# 	printerr("Error: AnimationTree does not have a condition parameter named ", condition_name)
	
	animation_tree.set(parameter_path, value)
	initial_anim = condition_name

## Process Dictionary signal sent from Dialogic	
## Take Arguments:
## Dictionary="{"animation":"Dance","character":"ArchLinux-Chan"}
func _on_dialogic_dictionary_signal(argument: Dictionary):
	
	print("A Dictionary signal was fired from Dialogic: ", argument)
	if argument["character"] != "All" && argument["character"] != character_name:
		return
	print("Animation signal from Dialogic for ", argument["character"])
	if argument["animation"] == null:
		return
	set_animation_condition(argument["animation"], true)
