extends AnimationTree

@export_category("Animation")
@export var relaxed_offset: float = 0.25
@export var dancing_offset: float = -0.35

@onready var character: CharacterBody3D = get_parent() as CharacterBody3D #parent
@onready var character_name: String = character.character_name

var total_time: int                   = 0
var mood_amount_path: String          = "parameters/expression/add_amount"
var dance_amount_path: String         = "parameters/dance/blend_amount"
var mood_state_path: String           = "parameters/mood/transition_request"
var straight_idle_amount_path: String = "parameters/straight/blend_amount"	
var viseme_amount_path: String        = "parameters/viseme/add_amount"
var viseme_state_path: String         = "parameters/syllabus/transition_request"


func _process(delta):
	total_time += delta
	update_anim(total_time)


func _ready():
	Dialogic.signal_event.connect(_on_dialogic_dictionary_signal)


func update_anim(time: float):
	var fnl     = FastNoiseLite.new()
	var noise   = fnl.get_noise_1d(time)
	var relaxed = clamp(noise / 2 + 0.5 + relaxed_offset, 0, 1)
	set(straight_idle_amount_path, 1 - relaxed)
	var dancing = clamp (noise / 2 + 0.5 + dancing_offset, 0, 1)
	set(dance_amount_path, dancing)


## Process Dictionary signal sent from Dialogic	
## Take Arguments:
## Dictionary="{"animation":"Dance","character":"ArchLinux-Chan"}
func _on_dialogic_dictionary_signal(argument: Dictionary) -> void:
	if argument["character"] != "All" && argument["character"] != character_name:
		return
	# Face expression
	if argument["mood"] == null && argument["mood_amount"] == null:
		return
	if argument["mood"] != null:
		var mood               = argument["mood"]
		var mood_amount: float = float(argument["mood_amount"]) / 100.0
		set(mood_amount_path, mood_amount)
		set(mood_state_path, mood)
	# Body expression
	if argument["dance_amount"] != null:
		dancing_offset = float(argument["dance_amount"]) / 100.0 - 0.5
	if argument["relax_amount"] != null:
		relaxed_offset = float(argument["relax_amount"]) / 100.0 - 0.5
