extends Node3D

@onready var load_button: Button = $UI/Control/TopMenuBar/MarginContainer/HBoxContainer/LeftSection/LoadButton
@onready var message_label: Label = $UI/Control/MessageLabel
@onready var file_dialog: FileDialog = $UI/FileDialog
@onready var model_pivot: Node3D = $ModelPivot

@onready var meta_panel: VBoxContainer = $UI/Control/MetaPanel
@onready var env_panel: VBoxContainer = $UI/Control/EnvPanel
@onready var expression_panel: VBoxContainer = $UI/Control/ExpressionPanel
@onready var motion_panel: VBoxContainer = $UI/Control/MotionPanel
@onready var version_option: OptionButton = $UI/Control/TopMenuBar/MarginContainer/HBoxContainer/LeftSection/VersionOption
@onready var home_button: Button = $UI/Control/TopMenuBar/MarginContainer/HBoxContainer/RightSection/HomeButton
@onready var camera_pivot: Node3D = $CameraPivot

@onready var info_button: Button = $UI/Control/TopMenuBar/MarginContainer/HBoxContainer/CenterSection/InfoButton
@onready var env_button: Button = $UI/Control/TopMenuBar/MarginContainer/HBoxContainer/CenterSection/EnvButton
@onready var expression_button: Button = $UI/Control/TopMenuBar/MarginContainer/HBoxContainer/CenterSection/ExpressionButton
@onready var motion_button: Button = $UI/Control/TopMenuBar/MarginContainer/HBoxContainer/CenterSection/MotionButton

## Path to the default bundled model (loaded from res:// via FileAccess bytes).
@export var default_model_path: String = "res://samples/character_samples/vrm/archlinux-chan_v0.1.1.vrm"

## HTTP fallback URL if the bundled model is not available (e.g. not in export list).
## Set to empty string to disable remote fallback.
@export var fallback_model_url: String = "https://raw.githubusercontent.com/Aestial/Godot-VRM-NovelEngine/main/samples/character_samples/vrm/archlinux-chan_v0.1.1.vrm"

var current_model: Node3D = null
var _is_web: bool = false
var _file_access_web: RefCounted = null # FileAccessWeb (only on web builds)

var _active_left_panel: String = ""
var _is_right_panel_open: bool = false

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
	
	# Connect menu panel triggers
	info_button.toggled.connect(_on_info_button_toggled)
	env_button.toggled.connect(_on_env_button_toggled)
	expression_button.toggled.connect(_on_expression_button_toggled)
	motion_button.toggled.connect(_on_motion_button_toggled)
	
	# Initial states: disable model-specific buttons
	info_button.disabled = true
	expression_button.disabled = true
	motion_button.disabled = true
	
	message_label.text = ""
	
	# Apply premium visual design styling
	_apply_theme_styling()
	
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
		
		# Close active panels and disable buttons
		info_button.disabled = true
		expression_button.disabled = true
		motion_button.disabled = true
		
		_toggle_right_panel(false)
		if _active_left_panel in ["expression", "motion"]:
			_toggle_left_panel("")
	
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
		
		# Close active panels and disable buttons
		info_button.disabled = true
		expression_button.disabled = true
		motion_button.disabled = true
		
		_toggle_right_panel(false)
		if _active_left_panel in ["expression", "motion"]:
			_toggle_left_panel("")
	
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
		
		# Enable tab buttons
		info_button.disabled = false
		expression_button.disabled = false
		motion_button.disabled = false
		
		_display_metadata(current_model)
		
		# Setup animation panels
		if expression_panel.has_method("setup"):
			expression_panel.setup(current_model)
		
		if motion_panel.has_method("setup"):
			motion_panel.setup(current_model)
			
		# Auto-open Info Panel on load
		_toggle_right_panel(true)
			
	else:
		message_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		message_label.text = "Error: " + result["error_msg"]
		
		# Close active panels and disable buttons
		info_button.disabled = true
		expression_button.disabled = true
		motion_button.disabled = true
		
		_toggle_right_panel(false)
		if _active_left_panel in ["expression", "motion"]:
			_toggle_left_panel("")

func _display_metadata(model: Node3D) -> void:
	var vrm_meta = model.get("vrm_meta")
	
	if vrm_meta == null or not (vrm_meta is Resource):
		print("[VRMViewer] vrm_meta unavailable for this model")
		info_button.disabled = true
		_toggle_right_panel(false)
		return
	
	info_button.disabled = false
	
	if meta_panel.has_method("display_metadata"):
		meta_panel.display_metadata(vrm_meta)

# --- Menu Button Handlers & Animations ---

func _on_info_button_toggled(pressed: bool) -> void:
	_toggle_right_panel(pressed)

func _on_env_button_toggled(pressed: bool) -> void:
	if pressed:
		_toggle_left_panel("env")
	else:
		if _active_left_panel == "env":
			_toggle_left_panel("")

func _on_expression_button_toggled(pressed: bool) -> void:
	if pressed:
		_toggle_left_panel("expression")
	else:
		if _active_left_panel == "expression":
			_toggle_left_panel("")

func _on_motion_button_toggled(pressed: bool) -> void:
	if pressed:
		_toggle_left_panel("motion")
	else:
		if _active_left_panel == "motion":
			_toggle_left_panel("")

func _toggle_left_panel(panel_name: String) -> void:
	if panel_name != "":
		if panel_name != "env": env_button.set_pressed_no_signal(false)
		if panel_name != "expression": expression_button.set_pressed_no_signal(false)
		if panel_name != "motion": motion_button.set_pressed_no_signal(false)
		
	var next_panel: Control = null
	if panel_name == "env":
		next_panel = env_panel
	elif panel_name == "expression":
		next_panel = expression_panel
	elif panel_name == "motion":
		next_panel = motion_panel
		
	var prev_panel: Control = null
	if _active_left_panel == "env":
		prev_panel = env_panel
	elif _active_left_panel == "expression":
		prev_panel = expression_panel
	elif _active_left_panel == "motion":
		prev_panel = motion_panel

	if prev_panel and prev_panel != next_panel:
		_animate_panel_slide(prev_panel, false, false)
		
	if next_panel:
		_animate_panel_slide(next_panel, true, false)
		
	_active_left_panel = panel_name
	_update_menu_button_visuals()

func _toggle_right_panel(open: bool) -> void:
	_is_right_panel_open = open
	info_button.set_pressed_no_signal(open)
	_animate_panel_slide(meta_panel, open, true)
	_update_menu_button_visuals()

func _animate_panel_slide(panel: Control, open: bool, is_right_side: bool) -> void:
	if panel.has_meta("active_tween"):
		var active_tween = panel.get_meta("active_tween")
		if active_tween and active_tween.is_valid():
			active_tween.kill()
			
	if panel.has_meta("hide_tween"):
		var hide_tween = panel.get_meta("hide_tween")
		if hide_tween and hide_tween.is_valid():
			hide_tween.kill()

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel.set_meta("active_tween", tween)
	
	var target_left: float
	var target_right: float
	var target_alpha: float = 1.0 if open else 0.0
	
	if is_right_side:
		target_left = -320.0 if open else 20.0
		target_right = -20.0 if open else 320.0
	else:
		target_left = 20.0 if open else -320.0
		target_right = 320.0 if open else -20.0
		
	if open:
		panel.show()
		
	tween.tween_property(panel, "offset_left", target_left, 0.35)
	tween.tween_property(panel, "offset_right", target_right, 0.35)
	tween.tween_property(panel, "modulate:a", target_alpha, 0.35)
	
	if not open:
		var timer_tween = create_tween()
		panel.set_meta("hide_tween", timer_tween)
		timer_tween.tween_interval(0.35)
		timer_tween.tween_callback(panel.hide)

func _apply_theme_styling() -> void:
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.07, 0.07, 0.09, 0.85)
	bar_style.corner_radius_top_left = 12
	bar_style.corner_radius_top_right = 12
	bar_style.corner_radius_bottom_left = 12
	bar_style.corner_radius_bottom_right = 12
	bar_style.border_width_left = 1
	bar_style.border_width_top = 1
	bar_style.border_width_right = 1
	bar_style.border_width_bottom = 1
	bar_style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	bar_style.shadow_color = Color(0, 0, 0, 0.3)
	bar_style.shadow_size = 10
	bar_style.shadow_offset = Vector2(0, 4)
	
	var top_menu_bar = $UI/Control/TopMenuBar
	top_menu_bar.add_theme_stylebox_override("panel", bar_style)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.07, 0.09, 0.85)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	panel_style.shadow_color = Color(0, 0, 0, 0.25)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0, 3)
	
	meta_panel.get_node("PanelContainer").add_theme_stylebox_override("panel", panel_style)
	expression_panel.get_node("PanelContainer").add_theme_stylebox_override("panel", panel_style)
	motion_panel.get_node("PanelContainer").add_theme_stylebox_override("panel", panel_style)
	env_panel.get_node("PanelContainer").add_theme_stylebox_override("panel", panel_style)
	
	var btn_normal := StyleBoxEmpty.new()
	
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	btn_hover.corner_radius_top_left = 8
	btn_hover.corner_radius_top_right = 8
	btn_hover.corner_radius_bottom_left = 8
	btn_hover.corner_radius_bottom_right = 8
	
	var buttons = [
		load_button,
		home_button,
		info_button,
		env_button,
		expression_button,
		motion_button
	]
	
	for btn in buttons:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_hover)
		btn.add_theme_stylebox_override("focus", btn_normal)
		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		
	var opt_style_normal := StyleBoxFlat.new()
	opt_style_normal.bg_color = Color(1.0, 1.0, 1.0, 0.04)
	opt_style_normal.corner_radius_top_left = 8
	opt_style_normal.corner_radius_top_right = 8
	opt_style_normal.corner_radius_bottom_left = 8
	opt_style_normal.corner_radius_bottom_right = 8
	opt_style_normal.border_width_left = 1
	opt_style_normal.border_width_top = 1
	opt_style_normal.border_width_right = 1
	opt_style_normal.border_width_bottom = 1
	opt_style_normal.border_color = Color(1.0, 1.0, 1.0, 0.06)
	
	var opt_style_hover := StyleBoxFlat.new()
	opt_style_hover.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	opt_style_hover.corner_radius_top_left = 8
	opt_style_hover.corner_radius_top_right = 8
	opt_style_hover.corner_radius_bottom_left = 8
	opt_style_hover.corner_radius_bottom_right = 8
	opt_style_hover.border_width_left = 1
	opt_style_hover.border_width_top = 1
	opt_style_hover.border_width_right = 1
	opt_style_hover.border_width_bottom = 1
	opt_style_hover.border_color = Color(1.0, 1.0, 1.0, 0.12)

	version_option.add_theme_stylebox_override("normal", opt_style_normal)
	version_option.add_theme_stylebox_override("hover", opt_style_hover)
	version_option.add_theme_stylebox_override("focus", opt_style_normal)
	version_option.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	version_option.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	
	_update_menu_button_visuals()

func _update_menu_button_visuals() -> void:
	var active_tab_style := StyleBoxFlat.new()
	active_tab_style.bg_color = Color(0.0, 0.6, 1.0, 0.12)
	active_tab_style.corner_radius_top_left = 8
	active_tab_style.corner_radius_top_right = 8
	active_tab_style.corner_radius_bottom_left = 8
	active_tab_style.corner_radius_bottom_right = 8
	active_tab_style.border_width_bottom = 2
	active_tab_style.border_color = Color(0.0, 0.75, 1.0)
	
	var normal_tab_style := StyleBoxEmpty.new()
	
	var tabs = {
		info_button: _is_right_panel_open,
		env_button: _active_left_panel == "env",
		expression_button: _active_left_panel == "expression",
		motion_button: _active_left_panel == "motion"
	}
	
	for btn in tabs.keys():
		var is_active = tabs[btn]
		if is_active:
			btn.add_theme_stylebox_override("normal", active_tab_style)
			btn.add_theme_stylebox_override("hover", active_tab_style)
			btn.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(0.4, 0.85, 1.0))
		else:
			btn.add_theme_stylebox_override("normal", normal_tab_style)
			btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
