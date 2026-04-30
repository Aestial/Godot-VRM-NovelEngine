extends Node3D

@onready var load_button: Button = $UI/Control/LoadButton
@onready var message_label: Label = $UI/Control/MessageLabel
@onready var file_dialog: FileDialog = $UI/FileDialog
@onready var model_pivot: Node3D = $ModelPivot

@onready var meta_panel: VBoxContainer = $UI/Control/MetaPanel
@onready var version_option: OptionButton = $UI/Control/VersionOption
@onready var home_button: Button = $UI/Control/HomeButton
@onready var camera_pivot: Node3D = $CameraPivot

## Path to the default bundled model (loaded from res:// via FileAccess bytes).
@export var default_model_path: String = "res://samples/character_samples/vrm/Brayan.vrm"

## HTTP fallback URL if the bundled model is not available (e.g. not in export list).
## Set to empty string to disable remote fallback.
@export var fallback_model_url: String = "https://raw.githubusercontent.com/Aestial/Godot-VRM-NovelEngine/main/samples/character_samples/vrm/vagonera.vrm"

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
	
	# Load default model via fallback chain
	_load_default_model()

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
		var file_path: String = files[0]
		var ext: String = file_path.get_extension().to_lower()
		if ext == "vrm" or ext == "vrma":
			_on_file_selected(file_path)
		else:
			message_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			message_label.text = "Error: Please drop a valid .vrm file."

# --- Default model fallback chain ---

func _load_default_model() -> void:
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.text = "Loading default model..."
	
	await get_tree().process_frame
	
	# Step 1: Try loading from bundled res:// path (works on all platforms)
	if default_model_path != "" and FileAccess.file_exists(default_model_path):
		print("[VRMViewer] Trying bundled model: ", default_model_path)
		var force_version: int = version_option.get_selected_id()
		var result: Dictionary = VRMLoader.load_vrm_from_res(default_model_path, force_version)
		if result["success"]:
			_apply_load_result(result)
			return
		else:
			print("[VRMViewer] Bundled model failed: ", result["error_msg"])
	else:
		print("[VRMViewer] Bundled model not found at: ", default_model_path)
	
	# Step 2: Try HTTP download from fallback URL
	if fallback_model_url != "":
		print("[VRMViewer] Trying remote fallback: ", fallback_model_url)
		message_label.text = "Downloading default model..."
		_download_remote_model(fallback_model_url)
		return
	
	# Step 3: No model available — show user-friendly message
	_show_no_default_model_message()

func _download_remote_model(url: String) -> void:
	var http_request := HTTPRequest.new()
	http_request.use_threads = not _is_web # Threads not available on web
	add_child(http_request)
	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http_request.queue_free()
			_on_remote_model_downloaded(result, response_code, body)
	)
	
	var err := http_request.request(url)
	if err != OK:
		http_request.queue_free()
		print("[VRMViewer] HTTP request failed to start: ", err)
		_show_no_default_model_message()

func _on_remote_model_downloaded(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[VRMViewer] Remote download failed (result=%d, code=%d)" % [result, response_code])
		_show_no_default_model_message()
		return
	
	print("[VRMViewer] Remote model downloaded (%d bytes), loading..." % body.size())
	
	var force_version: int = version_option.get_selected_id()
	var load_result: Dictionary = VRMLoader.load_vrm_from_buffer(body, force_version)
	
	if load_result["success"]:
		_apply_load_result(load_result)
	else:
		print("[VRMViewer] Remote model parse failed: ", load_result["error_msg"])
		_show_no_default_model_message()

func _show_no_default_model_message() -> void:
	message_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	message_label.text = "Click 'Load VRM' to get started."

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
	var result: Dictionary
	
	# Use buffer-based loading for res:// paths (cross-platform safe),
	# file-based loading for absolute paths (desktop only)
	if path.begins_with("res://") or path.begins_with("user://"):
		result = VRMLoader.load_vrm_from_res(path, force_version)
	else:
		result = VRMLoader.load_vrm(path, force_version)
	
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
