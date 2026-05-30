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

@onready var logs_button: Button = $UI/Control/TopMenuBar/MarginContainer/HBoxContainer/CenterSection/LogsButton
@onready var modal_overlay: ColorRect = $UI/Control/ModalOverlay
@onready var status_modal: PanelContainer = $UI/Control/StatusModal
@onready var modal_title: Label = $UI/Control/StatusModal/MarginContainer/VBoxContainer/ModalTitle
@onready var spinner_control: Control = $UI/Control/StatusModal/MarginContainer/VBoxContainer/SpinnerControl
@onready var modal_desc: Label = $UI/Control/StatusModal/MarginContainer/VBoxContainer/ModalDesc
@onready var dismiss_button: Button = $UI/Control/StatusModal/MarginContainer/VBoxContainer/DismissButton

@onready var log_panel: VBoxContainer = $UI/Control/LogPanel
@onready var log_scroll: ScrollContainer = $UI/Control/LogPanel/PanelContainer/MarginContainer/VBoxContainer/LogScroll
@onready var log_list: VBoxContainer = $UI/Control/LogPanel/PanelContainer/MarginContainer/VBoxContainer/LogScroll/LogList
@onready var clear_logs_button: Button = $UI/Control/LogPanel/ClearLogsButton

## Path to the default bundled model (loaded from res:// via FileAccess bytes).
@export var default_model_path: String = "res://samples/character_samples/vrm/archlinux-chan_v0.1.1.vrm"

## HTTP fallback URL if the bundled model is not available (e.g. not in export list).
## Set to empty string to disable remote fallback.
@export var fallback_model_url: String = "https://raw.githubusercontent.com/Aestial/Godot-VRM-NovelEngine/main/samples/character_samples/vrm/archlinux-chan_v0.1.1.vrm"

var current_model: Node3D = null
var _is_web: bool = false
var _file_access_web: RefCounted = null # FileAccessWeb (only on web builds)

var _active_left_panel: String = ""
var _active_right_panel: String = ""

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
	logs_button.toggled.connect(_on_logs_button_toggled)
	env_button.toggled.connect(_on_env_button_toggled)
	expression_button.toggled.connect(_on_expression_button_toggled)
	motion_button.toggled.connect(_on_motion_button_toggled)
	
	clear_logs_button.pressed.connect(_on_clear_logs_pressed)
	dismiss_button.pressed.connect(_on_dismiss_button_pressed)
	
	# Initial states: disable model-specific buttons
	info_button.disabled = true
	expression_button.disabled = true
	motion_button.disabled = true
	
	message_label.text = ""
	
	# Set initial menu button variations
	_update_menu_button_visuals()
	
	# Set up landing welcome screen
	_show_welcome_modal()
	
	# Load default model via fallback chain
	_load_default_model()

func _on_home_button_pressed() -> void:
	if camera_pivot.has_method("reset_camera"):
		camera_pivot.reset_camera()

func _on_load_button_pressed() -> void:
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
			update_status("Error: Please drop a valid .vrm file.", "error")
			_show_error_modal("Please drop a valid .vrm file.")

# --- Default model fallback chain ---

func _load_default_model() -> void:
	_start_loading("Default Model")
	update_status("Loading default model...", "info")
	
	await get_tree().process_frame
	
	# Step 1: Try loading from bundled res:// path (works on all platforms)
	if default_model_path != "" and FileAccess.file_exists(default_model_path):
		update_status("Trying bundled model: " + default_model_path, "info")
		var force_version: int = version_option.get_selected_id()
		var result: Dictionary = VRMLoader.load_vrm_from_res(default_model_path, force_version)
		if result["success"]:
			_apply_load_result(result)
			return
		else:
			update_status("Bundled model failed: " + result["error_msg"], "error")
	else:
		update_status("Bundled model not found at: " + default_model_path, "info")
	
	# Step 2: Try HTTP download from fallback URL
	if fallback_model_url != "":
		update_status("Trying remote fallback: " + fallback_model_url, "info")
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
	
	update_status("Downloading remote default model...", "info")
	var err := http_request.request(url)
	if err != OK:
		http_request.queue_free()
		update_status("HTTP request failed to start: " + str(err), "error")
		_show_no_default_model_message()

func _on_remote_model_downloaded(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		update_status("Remote download failed (result=%d, code=%d)" % [result, response_code], "error")
		_show_no_default_model_message()
		return
	
	update_status("Remote model downloaded (%d bytes), parsing..." % body.size(), "info")
	
	var force_version: int = version_option.get_selected_id()
	var load_result: Dictionary = VRMLoader.load_vrm_from_buffer(body, force_version)
	
	if load_result["success"]:
		_apply_load_result(load_result)
	else:
		update_status("Remote model parse failed: " + load_result["error_msg"], "error")
		_show_no_default_model_message()

func _show_no_default_model_message() -> void:
	update_status("No avatar loaded. Select a model to begin.", "info")
	_show_welcome_modal()

# --- Web file upload handlers ---

func _on_web_file_loaded(file_name: String, _file_type: String, base64_data: String) -> void:
	if current_model:
		current_model.queue_free()
		current_model = null
		
		# Close active panels and disable buttons
		info_button.disabled = true
		expression_button.disabled = true
		motion_button.disabled = true
		
		if _active_right_panel == "info":
			_toggle_right_panel("")
		if _active_left_panel in ["expression", "motion"]:
			_toggle_left_panel("")
	
	_start_loading(file_name)
	update_status("Loading uploaded file '%s'..." % file_name, "info")
	
	await get_tree().process_frame
	
	# Decode base64 to raw bytes
	var raw_data: PackedByteArray = Marshalls.base64_to_raw(base64_data)
	
	var force_version: int = version_option.get_selected_id()
	var result: Dictionary = VRMLoader.load_vrm_from_buffer(raw_data, force_version)
	
	_apply_load_result(result)

func _on_web_file_error() -> void:
	update_status("Error: Failed to read the uploaded web file.", "error")
	_show_error_modal("Failed to read the uploaded file.")

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
		
		if _active_right_panel == "info":
			_toggle_right_panel("")
		if _active_left_panel in ["expression", "motion"]:
			_toggle_left_panel("")
	
	var file_name = path.get_file()
	_start_loading(file_name)
	update_status("Loading local file '%s'..." % file_name, "info")
	
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
		
		update_status("Avatar loaded successfully!", "success")
		
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
			
		# Auto-open Info Panel on load (if not currently checking logs)
		if _active_right_panel != "log":
			_toggle_right_panel("info")
			
		_transition_to_success_toast()
			
	else:
		update_status("Error loading avatar: " + result["error_msg"], "error")
		
		# Close active panels and disable buttons
		info_button.disabled = true
		expression_button.disabled = true
		motion_button.disabled = true
		
		if _active_right_panel == "info":
			_toggle_right_panel("")
		if _active_left_panel in ["expression", "motion"]:
			_toggle_left_panel("")
			
		_show_error_modal(result["error_msg"])

func _display_metadata(model: Node3D) -> void:
	var vrm_meta = model.get("vrm_meta")
	
	if vrm_meta == null or not (vrm_meta is Resource):
		update_status("Warning: metadata unavailable for this model", "info")
		info_button.disabled = true
		if _active_right_panel == "info":
			_toggle_right_panel("")
		return
	
	info_button.disabled = false
	
	if meta_panel.has_method("display_metadata"):
		meta_panel.display_metadata(vrm_meta)

# --- Menu Button Handlers & Animations ---

func _on_info_button_toggled(pressed: bool) -> void:
	if pressed:
		_toggle_right_panel("info")
	else:
		if _active_right_panel == "info":
			_toggle_right_panel("")

func _on_logs_button_toggled(pressed: bool) -> void:
	if pressed:
		_toggle_right_panel("log")
	else:
		if _active_right_panel == "log":
			_toggle_right_panel("")

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

func _toggle_right_panel(panel_name: String) -> void:
	if panel_name != "":
		if panel_name != "info": info_button.set_pressed_no_signal(false)
		if panel_name != "log": logs_button.set_pressed_no_signal(false)
		
	var next_panel: Control = null
	if panel_name == "info":
		next_panel = meta_panel
	elif panel_name == "log":
		next_panel = log_panel
		
	var prev_panel: Control = null
	if _active_right_panel == "info":
		prev_panel = meta_panel
	elif _active_right_panel == "log":
		prev_panel = log_panel

	if prev_panel and prev_panel != next_panel:
		_animate_panel_slide(prev_panel, false, true)
		
	if next_panel:
		_animate_panel_slide(next_panel, true, true)
		
	_active_right_panel = panel_name
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

func _update_menu_button_visuals() -> void:
	var tabs = {
		info_button: _active_right_panel == "info",
		logs_button: _active_right_panel == "log",
		env_button: _active_left_panel == "env",
		expression_button: _active_left_panel == "expression",
		motion_button: _active_left_panel == "motion"
	}
	
	for btn in tabs.keys():
		var is_active = tabs[btn]
		if is_active:
			btn.theme_type_variation = "MenuTabButton"
		else:
			btn.theme_type_variation = ""

# --- Status Modal & Log History Helpers ---

func add_log(message: String, type: String = "info") -> void:
	var time = Time.get_time_dict_from_system()
	var time_str = "%02d:%02d:%02d" % [time.hour, time.minute, time.second]
	
	var log_label = RichTextLabel.new()
	log_label.fit_content = true
	log_label.selection_enabled = true
	log_label.bbcode_enabled = true
	
	var color_tag = "white"
	if type == "error":
		color_tag = "#ff5555" # Soft red
	elif type == "success":
		color_tag = "#55ff55" # Soft green
	elif type == "info":
		color_tag = "#aaaaaa" # Muted gray
		
	log_label.text = "[color=#777777][%s][/color] [color=%s]%s[/color]" % [time_str, color_tag, message]
	
	log_list.add_child(log_label)
	
	# Auto scroll to bottom
	await get_tree().process_frame
	if log_scroll:
		var v_scroll = log_scroll.get_v_scroll_bar()
		if v_scroll:
			log_scroll.scroll_vertical = int(v_scroll.max_value)

func update_status(message: String, type: String = "info") -> void:
	add_log(message, type)
	
	if modal_desc:
		modal_desc.text = message
		if type == "error":
			modal_desc.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif type == "success":
			modal_desc.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			modal_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.82))

func _show_welcome_modal() -> void:
	_reset_modal_to_center()
	modal_title.text = "Welcome to VRM Viewer"
	modal_desc.text = "Click 'Load VRM' in the top-left to select your avatar."
	spinner_control.hide()
	dismiss_button.text = "OK"
	dismiss_button.show()
	status_modal.show()
	status_modal.modulate.a = 1.0
	add_log("Welcome to VRM Viewer! Ready to load avatars.", "info")

func _show_error_modal(error_msg: String) -> void:
	_reset_modal_to_center()
	modal_title.text = "Loading Failed"
	modal_desc.text = error_msg
	modal_desc.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	spinner_control.hide()
	dismiss_button.text = "Dismiss"
	dismiss_button.show()
	status_modal.show()
	status_modal.modulate.a = 1.0

func _start_loading(source_name: String) -> void:
	# Show input blocker overlay
	modal_overlay.show()
	
	_reset_modal_to_center()
	modal_title.text = "Loading Avatar"
	modal_desc.text = "Loading " + source_name + "..."
	modal_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.82))
	spinner_control.show()
	dismiss_button.hide()
	status_modal.show()
	status_modal.modulate.a = 1.0

func _reset_modal_to_center() -> void:
	# Kill any running modal tweens
	if status_modal.has_meta("active_tween"):
		var active_tween = status_modal.get_meta("active_tween")
		if active_tween and active_tween.is_valid():
			active_tween.kill()
			
	if status_modal.has_meta("hide_tween"):
		var hide_tween = status_modal.get_meta("hide_tween")
		if hide_tween and hide_tween.is_valid():
			hide_tween.kill()

	status_modal.anchors_preset = Control.PRESET_CENTER
	status_modal.anchor_left = 0.5
	status_modal.anchor_right = 0.5
	status_modal.anchor_top = 0.5
	status_modal.anchor_bottom = 0.5
	status_modal.offset_left = -180.0
	status_modal.offset_right = 180.0
	status_modal.offset_top = -100.0
	status_modal.offset_bottom = 100.0
	status_modal.theme_type_variation = "StatusModal"

func _transition_to_success_toast() -> void:
	modal_overlay.hide()
	spinner_control.hide()
	dismiss_button.hide()
	
	modal_title.text = "Success"
	modal_desc.text = "Avatar loaded successfully!"
	modal_desc.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	
	status_modal.theme_type_variation = "SuccessModal"
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	status_modal.set_meta("active_tween", tween)
	
	tween.tween_property(status_modal, "anchor_top", 0.0, 0.45)
	tween.tween_property(status_modal, "anchor_bottom", 0.0, 0.45)
	tween.tween_property(status_modal, "offset_left", -150.0, 0.45)
	tween.tween_property(status_modal, "offset_right", 150.0, 0.45)
	tween.tween_property(status_modal, "offset_top", 80.0, 0.45)
	tween.tween_property(status_modal, "offset_bottom", 140.0, 0.45)
	
	var hide_timer = create_tween()
	status_modal.set_meta("hide_tween", hide_timer)
	hide_timer.tween_interval(2.5)
	hide_timer.tween_property(status_modal, "modulate:a", 0.0, 0.3)
	hide_timer.tween_callback(status_modal.hide)

func _on_dismiss_button_pressed() -> void:
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(status_modal, "modulate:a", 0.0, 0.25)
	
	var timer = create_tween()
	timer.tween_interval(0.25)
	timer.tween_callback(status_modal.hide)

func _on_clear_logs_pressed() -> void:
	for child in log_list.get_children():
		child.queue_free()
	add_log("Logs cleared.", "info")
