extends Node3D

@onready var load_button: Button = $UI/Control/LoadButton
@onready var error_label: Label = $UI/Control/ErrorLabel
@onready var file_dialog: FileDialog = $UI/FileDialog
@onready var model_pivot: Node3D = $ModelPivot

@onready var meta_container: VBoxContainer = $UI/Control/MetaContainer
@onready var meta_panel: Panel = $UI/Control/MetaContainer/MetaPanel
@onready var toggle_meta_button: Button = $UI/Control/MetaContainer/ToggleMetaButton
@onready var version_option: OptionButton = $UI/Control/VersionOption
@onready var home_button: Button = $UI/Control/HomeButton
@onready var camera_pivot: Node3D = $CameraPivot

var current_model: Node3D = null

func _ready() -> void:
	load_button.pressed.connect(_on_load_button_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	toggle_meta_button.pressed.connect(_on_toggle_meta_button_pressed)
	home_button.pressed.connect(_on_home_button_pressed)
	
	error_label.text = ""
	meta_container.hide()
	
	# Wire up dependencies
	camera_pivot.target_model_pivot = model_pivot
	
	# Load default model
	_on_file_selected("res://samples/character_samples/vrm/Brayan.vrm")

func _on_home_button_pressed() -> void:
	if camera_pivot.has_method("reset_camera"):
		camera_pivot.reset_camera()

func _on_toggle_meta_button_pressed() -> void:
	if meta_panel.has_method("toggle_expansion"):
		meta_panel.toggle_expansion()
		toggle_meta_button.text = "Hide Info" if meta_panel.is_expanded else "Show Info"

func _on_load_button_pressed() -> void:
	error_label.text = ""
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	if current_model:
		current_model.queue_free()
		current_model = null
		meta_container.hide()
	
	error_label.add_theme_color_override("font_color", Color.WHITE)
	error_label.text = "Loading... Please wait."
	
	await get_tree().process_frame
	
	var force_version: int = version_option.get_selected_id()
	var result: Dictionary = VRMLoader.load_vrm(path, force_version)
	
	if result["success"]:
		var ps: PackedScene = PackedScene.new()
		ps.pack(result["node"])
		current_model = ps.instantiate()
		
		model_pivot.add_child(current_model)
		
		if camera_pivot.has_method("reset_camera"):
			camera_pivot.reset_camera()
		else:
			model_pivot.rotation.y = PI # Fallback
		
		error_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		error_label.text = "Loaded successfully!"
		
		_display_metadata(current_model)
			
	else:
		error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		error_label.text = "Error: " + result["error_msg"]

func _display_metadata(model: Node3D) -> void:
	var vrm_meta = model.get("vrm_meta")
	
	if vrm_meta == null or not (vrm_meta is Resource):
		print("[VRMViewer] vrm_meta unavailable for this model")
		meta_container.hide()
		return
	
	meta_container.show()
	toggle_meta_button.text = "Hide Info" if meta_panel.is_expanded else "Show Info"
	
	if meta_panel.has_method("display_metadata"):
		meta_panel.display_metadata(vrm_meta)
