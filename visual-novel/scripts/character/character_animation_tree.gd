class_name CharacterAnimationTree extends AnimationTree

@export_category("Blinking")
# Configuration parameters
@export var blink_duration: float = 0.2 # Blink animation duration
@export var blink_frequency: float = 1.0  # Higher = more frequent blinks
@export var blink_sharpness: float = 10.0  # Higher = sharper blinks
@export var blink_threshold: float = 0.26  # Higher = fewer but more pronounced blinks
@export var asymmetry_offset: float = 0.2  # Time offset between left/right eyes

@onready var novel_character: NovelCharacter = get_parent() as NovelCharacter
@onready var dialogic_character: DialogicCharacter = novel_character.dialogic_character
@onready var character_name: String = dialogic_character.display_name

var mood_state_path: String           = "parameters/FaceExpression/mood/transition_request"	
var mood_amount_path: String          = "parameters/FaceExpression/mood_amount/blend_amount"
var viseme_state_path: String         = "parameters/FaceExpression/viseme/transition_request"
var viseme_amount_path: String        = "parameters/FaceExpression/viseme_amount/blend_amount"
var motion_amount: String 			  = "parameters/Locomotion/Motion/blend_position"
var left_eye_blink_amount: String	  = "parameters/LeftBlink/blend_position"
var right_eye_blink_amount: String	  = "parameters/RightBlink/blend_position"

# Random animation
var fnl: FastNoiseLite
var total_time: float = 0.0
# Forced blink control
var is_forced_blink: bool = false
var forced_blink_value: float = 0.0

func _ready():
	setup_noise()	
	Dialogic.signal_event.connect(_on_dialogic_dictionary_signal)
	
func setup_noise():
	fnl = FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_CELLULAR
	fnl.frequency = blink_frequency
	fnl.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	fnl.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	fnl.seed = randi()

func reset() -> void:
	set(mood_amount_path, 0)
	set(viseme_amount_path, 0)
	set(motion_amount, 0)

func _process(delta):
	total_time += delta
	
	# Get eyelid values
	var left_eyelid: float = get_smooth_eyelid_value(0.0, 0.0)
	var right_eyelid: float = get_smooth_eyelid_value(1.0, asymmetry_offset)

	apply_eyelid_values(left_eyelid, right_eyelid)
	
func apply_eyelid_values(left_value: float, right_value: float):
	"""
	Apply the calculated values to your character's eyelids
	This is where you'd connect to your actual character system
	"""
#	print("Left eyelid: ", left_value, " | Right eyelid: ", right_value)
	set(left_eye_blink_amount, left_value)
	set(right_eye_blink_amount, right_value)
	
	
func get_smooth_eyelid_value(x_position: float, time_offset: float = 0.0) -> float:
	"""
	Get smoothed eyelid value with multiple samples for more natural movement
	"""
	# If we're in a forced blink, return the forced value
	if is_forced_blink:
		return forced_blink_value
		
	var current_time = total_time + time_offset
	var base_input = x_position + current_time
	
	# Sample multiple points and average for smoother transitions
	var samples: int = 3
	var total: float = 0.0
	
	for i in range(samples):
		var sample_offset = (i - (samples - 1) * 0.5) * 0.1
		var noise_input = base_input + sample_offset
		var raw_value = fnl.get_noise_1d(noise_input)
		var normalized_value = (raw_value + 1.0) / 2.0
		var peak_value = 1.0 - normalized_value
		total += process_eyelid_peak(peak_value)
		
	return total / samples
	
func process_eyelid_peak(raw_peak: float) -> float:
	var sharp_peak = pow(raw_peak, blink_sharpness)
	if sharp_peak < blink_threshold:
		return 0.0
	force_blink(blink_duration) # TODO: Fix forced blink
	return (sharp_peak - blink_threshold) / (1.0 - blink_threshold)
	
# Force a blink with smooth animation
func force_blink(duration: float = 0.2):
	# Start the blink coroutine
	_blink_coroutine(duration)

# Coroutine for smooth blinking animation
func _blink_coroutine(duration: float):
	is_forced_blink = true
	
	var half_duration = duration * 0.5
	
	# Eyelids closing (0.0 to 1.0)
	var t: float = 0.0
	while t < half_duration:
		forced_blink_value = t / half_duration  # 0.0 to 1.0
		t += get_process_delta_time()
		if get_tree():
			await get_tree().process_frame
	
	# Eyelids fully closed
	forced_blink_value = 1.0
	await get_tree().create_timer(0.05).timeout  # Brief pause while closed
	
	# Eyelids opening (1.0 to 0.0)
	t = 0.0
	
	while t < half_duration:
		forced_blink_value = 1.0 - (t / half_duration)  # 1.0 to 0.0
		t += get_process_delta_time()
		await get_tree().process_frame
	
	# Reset
	forced_blink_value = 0.0
	is_forced_blink = false

# Alternative version using Tween for smoother animation
func force_blink_with_tween(duration: float = 0.2):
	is_forced_blink = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Close eyes
	tween.tween_method(_set_forced_blink_value, 0.0, 1.0, duration * 0.4)
	# Brief pause
	tween.tween_interval(duration * 0.2)
	# Open eyes
	tween.tween_method(_set_forced_blink_value, 1.0, 0.0, duration * 0.4)
	
	await tween.finished
	is_forced_blink = false

func _set_forced_blink_value(value: float):
	forced_blink_value = value

# Force blink for one eye only
func force_blink_single_eye(is_left_eye: bool, duration: float = 0.2):
	# You could extend this to handle single eye blinking
	# For now, we'll just do both eyes
	if is_left_eye: 
		force_blink_with_tween(duration)

## Process Dictionary signal sent from Dialogic	
## Take Arguments:
## Dictionary="{"animation":"Dance","character":"ArchLinux-Chan"}
func _on_dialogic_dictionary_signal(argument: Dictionary) -> void:
	if argument["character"] != "All" && argument["character"] != character_name:
		return
	# Face expression
	if argument["mood"] == null && argument["amount"] == null:
		return
	if argument["mood"] != null:
		var mood               = argument["mood"]
		var mood_amount: float = float(argument["amount"])
		set(mood_amount_path, mood_amount)
		set(mood_state_path, mood)
		#print("Setting " + mood + " mood for " + character_name + ": " + mood + " with amount: " + str(mood_amount))

# Test function - call this to trigger a blink
#func _input(event):
#	if event is InputEventKey and event.pressed:
#		if event.keycode == KEY_1:
#			force_blink(blink_duration)  # Force blink when space is pressed
#		elif event.keycode == KEY_2:
#			force_blink_with_tween(blink_duration)  # Alternative tween version
