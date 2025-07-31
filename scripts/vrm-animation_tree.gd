extends AnimationTree

@export_category("Animation")
@export var initial_anim: String = "Idle"
@export var relaxed_base: float = 0.25
@export var twerk_blend_amount: float = -0.35

@onready var character: CharacterBody3D  = get_parent() as CharacterBody3D #parent
@onready var character_name: String = character.character_name

var total_time = 0
var relaxed_blend_path = "parameters/Idle_BlendTree/Straight_Relaxed/blend_amount"
var belly_twerk_blend_path = "parameters/Dance_BlendTree/Belly_Twerk/blend_amount"

func _process(delta):
	total_time += delta
	update_anim(total_time)

func _ready():
	Dialogic.signal_event.connect(_on_dialogic_dictionary_signal)
	
func update_anim(time: float):
	var fnl = FastNoiseLite.new()
	var noise = fnl.get_noise_1d(time)
	var relaxed = clamp(noise / 2 + 0.5 + relaxed_base, 0, 1)
	set(relaxed_blend_path, relaxed)	
	
	var twerk_blend = clamp (noise / 2 + 0.5 + twerk_blend_amount, 0, 1)
	set(belly_twerk_blend_path, twerk_blend)
	
func set_animation_condition(condition_name:String, value: bool):
	# Cancel previous anim
	if initial_anim != "":
		var path ="parameters/conditions/" + initial_anim
		set(path, false)
		
	# Construct the parameter path
	var parameter_path ="parameters/conditions/" + condition_name
	
	# Check if the parameter exists
	# if animation_tree.has_node(parameter_path):
	# 	print("Successful found condition parameter in AnimationTree called: ", condition_name)
		#Set the condition value
	# else:
	# 	printerr("Error: AnimationTree does not have a condition parameter named ", condition_name)
	
	set(parameter_path, value)
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
