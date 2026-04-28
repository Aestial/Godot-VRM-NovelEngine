extends Node3D

@onready var load_button: Button = $UI/Control/LoadButton
@onready var error_label: Label = $UI/Control/ErrorLabel
@onready var file_dialog: FileDialog = $UI/FileDialog
@onready var model_pivot: Node3D = $ModelPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot

@onready var meta_panel: Panel = $UI/Control/MetaPanel
@onready var title_label: Label = $UI/Control/MetaPanel/VBoxContainer/TitleLabel
@onready var author_label: Label = $UI/Control/MetaPanel/VBoxContainer/AuthorLabel
@onready var version_label: Label = $UI/Control/MetaPanel/VBoxContainer/VersionLabel
@onready var license_label: Label = $UI/Control/MetaPanel/VBoxContainer/LicenseLabel
@onready var reference_label: Label = $UI/Control/MetaPanel/VBoxContainer/ReferenceLabel
@onready var thumbnail_rect: TextureRect = $UI/Control/MetaPanel/VBoxContainer/ThumbnailRect
@onready var version_option: OptionButton = $UI/Control/VersionOption

var current_model: Node3D = null

# Camera control variables
var is_dragging: bool = false
var last_mouse_pos: Vector2
var zoom_level: float = 2.0
var min_zoom: float = 0.5
var max_zoom: float = 5.0
var zoom_speed: float = 0.2
var pan_speed: float = 0.005
var is_panning: bool = false

func _ready() -> void:
	load_button.pressed.connect(_on_load_button_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	error_label.text = ""
	meta_panel.hide()
	# Load default model
	_on_file_selected("res://samples/character_samples/vrm/Brayan.vrm")

func _on_load_button_pressed() -> void:
	error_label.text = ""
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	if current_model:
		current_model.queue_free()
		current_model = null
		meta_panel.hide()
	
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
		error_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		error_label.text = "Loaded successfully!"
		
		# Extract metadata from the loaded VRM model.
		# The V-Sekai plugin attaches a VRMTopLevel script to the root node
		# and sets "vrm_meta" as an @export property containing a vrm_meta Resource.
		_display_metadata(current_model)
			
	else:
		error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		error_label.text = "Error: " + result["error_msg"]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_panning = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_level = clamp(zoom_level - zoom_speed, min_zoom, max_zoom)
			_update_camera_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_level = clamp(zoom_level + zoom_speed, min_zoom, max_zoom)
			_update_camera_zoom()
			
	elif event is InputEventMouseMotion:
		if is_dragging:
			var delta: Vector2 = event.position - last_mouse_pos
			model_pivot.rotate_y(delta.x * 0.01)
			last_mouse_pos = event.position
		elif is_panning:
			var delta: Vector2 = event.position - last_mouse_pos
			# Pan the camera pivot
			camera_pivot.position.x -= delta.x * pan_speed
			camera_pivot.position.y += delta.y * pan_speed
			last_mouse_pos = event.position

func _update_camera_zoom() -> void:
	camera.position.z = zoom_level

func _display_metadata(model: Node3D) -> void:
	# The V-Sekai plugin sets vrm_meta as a script @export property on the root node
	# via VRMTopLevel.gd. We access it with Object.get() to avoid a hard class dependency.
	var vrm_meta = model.get("vrm_meta")
	
	# vrm_meta can be a freshly-allocated empty Resource if the plugin failed to
	# populate it (e.g. the VRM file lacks a meta block), so we check the title field.
	if vrm_meta == null or not (vrm_meta is Resource):
		print("[VRMViewer] vrm_meta unavailable for this model (type: ", typeof(vrm_meta), ")")
		return
	
	meta_panel.show()
	
	var title: String = vrm_meta.get("title") if vrm_meta.get("title") else ""
	title_label.text = "Title: " + (title if not title.is_empty() else "Unknown")
	
	var authors = vrm_meta.get("authors") if vrm_meta.get("authors") else PackedStringArray()
	author_label.text = "Author: " + (authors[0] if authors.size() > 0 else "Unknown")
	
	var version: String = vrm_meta.get("version") if vrm_meta.get("version") else ""
	version_label.text = "Version: " + (version if not version.is_empty() else "Unknown")
	
	var license: String = vrm_meta.get("license_name") if vrm_meta.get("license_name") else ""
	license_label.text = "License: " + (license if not license.is_empty() else "Unknown")

	var reference: String = vrm_meta.get("reference_information") if vrm_meta.get("reference_information") else ""
	reference_label.text = "Reference: " + (reference if not reference.is_empty() else "Unknown")
	
	var thumbnail: Texture = vrm_meta.get("thumbnail_image")
	if thumbnail:
		thumbnail_rect.texture = thumbnail
		thumbnail_rect.show()
	else:
		thumbnail_rect.hide()
