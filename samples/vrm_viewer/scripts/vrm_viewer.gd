extends Node3D

@onready var load_button: Button = $UI/Control/LoadButton
@onready var error_label: Label = $UI/Control/ErrorLabel
@onready var file_dialog: FileDialog = $UI/FileDialog
@onready var model_pivot: Node3D = $ModelPivot

var current_model: Node3D = null

func _ready() -> void:
	load_button.pressed.connect(_on_load_button_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	error_label.text = ""

func _on_load_button_pressed() -> void:
	error_label.text = ""
	# Show the file dialog so the user can select a .vrm file
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	# Clear any previously loaded model
	if current_model:
		current_model.queue_free()
		current_model = null
	
	error_label.add_theme_color_override("font_color", Color.WHITE)
	error_label.text = "Loading... Please wait."
	
	# Wait for one frame so the UI can update the "Loading..." text
	await get_tree().process_frame
	
	# Call our static loader
	var result = VRMLoader.load_vrm(path)
	
	if result["success"]:
		current_model = result["node"]
		model_pivot.add_child(current_model)
		error_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		error_label.text = "Loaded successfully!"
	else:
		error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		error_label.text = "Error: " + result["error_msg"]

# Optional: Rotate the model slowly for a better view
func _process(delta: float) -> void:
	if current_model:
		model_pivot.rotate_y(0.5 * delta)
