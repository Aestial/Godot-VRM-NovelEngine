extends Node3D

@onready var load_button: Button = $UI/Control/LoadButton
@onready var message_label: Label = $UI/Control/MessageLabel
@onready var file_dialog: FileDialog = $UI/FileDialog
@onready var model_pivot: Node3D = $ModelPivot

@onready var meta_panel: VBoxContainer = $UI/Control/MetaPanel
@onready var version_option: OptionButton = $UI/Control/VersionOption
@onready var home_button: Button = $UI/Control/HomeButton
@onready var camera_pivot: Node3D = $CameraPivot

var current_model: Node3D = null
var _is_web: bool = false
var _file_access_web: RefCounted = null # FileAccessWeb (only on web builds)

func _ready() -> void:
	_is_web = OS.get_name() == "Web"
	
	load_button.pressed.connect(_on_load_button_pressed)
	home_button.pressed.connect(_on_home_button_pressed)
	
	if _is_web:
		# Use FileAccessWeb plugin for browser file picker
		_file_access_web = FileAccessWeb.new()
		_file_access_web.loaded.connect(_on_web_file_loaded)
		_file_access_web.error.connect(_on_web_file_error)
		_file_access_web.upload_cancelled.connect(_on_web_upload_cancelled)
	else:
		# Use native FileDialog on desktop
		file_dialog.file_selected.connect(_on_file_selected)
	
	# Support for drag and drop files (especially useful for web exports)
	get_viewport().files_dropped.connect(_on_files_dropped)
	
	message_label.text = ""
	meta_panel.hide()
	
	# Wire up dependencies
	camera_pivot.target_model_pivot = model_pivot
	
	# Load default model
	_on_file_selected("res://samples/character_samples/vrm/Brayan.vrm")

func _on_home_button_pressed() -> void:
	if camera_pivot.has_method("reset_camera"):
		camera_pivot.reset_camera()

func _on_load_button_pressed() -> void:
	message_label.text = ""
	if _is_web:
		_file_access_web.open(".vrm")
	else:
		file_dialog.popup_centered()

func _on_files_dropped(files: PackedStringArray) -> void:
	if files.size() > 0:
		var file_path = files[0]
		var ext = file_path.get_extension().to_lower()
		if ext == "vrm" or ext == "vrma":
			_on_file_selected(file_path)
		else:
			message_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			message_label.text = "Error: Please drop a valid .vrm file."

# --- Web file upload handlers ---

func _on_web_file_loaded(file_name: String, _file_type: String, base64_data: String) -> void:
	if current_model:
		current_model.queue_free()
		current_model = null
		meta_panel.hide()
	
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.text = "Loading '%s'... Please wait." % file_name
	
	await get_tree().process_frame
	
	# Decode base64 to raw bytes
	var raw_data: PackedByteArray = Marshalls.base64_to_raw(base64_data)
	
	var force_version: int = version_option.get_selected_id()
	var result: Dictionary = VRMLoader.load_vrm_from_buffer(raw_data, force_version)
	
	_apply_load_result(result)

func _on_web_file_error() -> void:
	message_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	message_label.text = "Error: Failed to read the uploaded file."

func _on_web_upload_cancelled() -> void:
	# User cancelled the file picker — nothing to do
	pass

# --- Desktop file path handler ---

func _on_file_selected(path: String) -> void:
	if current_model:
		current_model.queue_free()
		current_model = null
		meta_panel.hide()
	
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.text = "Loading... Please wait."
	
	await get_tree().process_frame
	
	var force_version: int = version_option.get_selected_id()
	var result: Dictionary = VRMLoader.load_vrm(path, force_version)
	
	_apply_load_result(result)

# --- Shared result handling ---

func _apply_load_result(result: Dictionary) -> void:
	if result["success"]:
		var ps: PackedScene = PackedScene.new()
		ps.pack(result["node"])
		current_model = ps.instantiate()
		
		model_pivot.add_child(current_model)
		
		if camera_pivot.has_method("reset_camera"):
			camera_pivot.reset_camera()
		else:
			model_pivot.rotation.y = PI # Fallback
		
		message_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		message_label.text = "Loaded successfully!"
		
		_display_metadata(current_model)
			
	else:
		message_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		message_label.text = "Error: " + result["error_msg"]

func _display_metadata(model: Node3D) -> void:
	var vrm_meta = model.get("vrm_meta")
	
	if vrm_meta == null or not (vrm_meta is Resource):
		print("[VRMViewer] vrm_meta unavailable for this model")
		meta_panel.hide()
		return
	
	meta_panel.show()
	
	if meta_panel.has_method("display_metadata"):
		meta_panel.display_metadata(vrm_meta)
