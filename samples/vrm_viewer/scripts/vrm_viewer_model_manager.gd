extends Control

signal model_selected(path: String)
signal browse_local_requested()

@onready var recent_grid: FlowContainer = $"PanelContainer/MarginContainer/VBoxContainer/TabContainer/Recent Models/ScrollContainer/GridContainer"
@onready var bundled_grid: FlowContainer = $"PanelContainer/MarginContainer/VBoxContainer/TabContainer/Bundled Models/ScrollContainer/GridContainer"

@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var browse_button: Button = $PanelContainer/MarginContainer/VBoxContainer/LocalFilePanel/MarginContainer/FooterRow/BrowseButton
@onready var version_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/LocalFilePanel/MarginContainer/FooterRow/VersionOption

var RECENT_MODELS_FILE: String = "user://recent_models.json"
var THUMBNAILS_DIR: String = "user://thumbnails/"

var recent_models: Array = []
var bundled_models: Array = []

func _ready() -> void:
	close_button.pressed.connect(func(): hide())
	browse_button.pressed.connect(func(): 
		hide()
		browse_local_requested.emit()
	)
	
	DirAccess.make_dir_recursive_absolute(THUMBNAILS_DIR)
	
	_load_recent_models()
	_populate_bundled_models()

func open() -> void:
	show()
	_refresh_ui()

func get_force_version() -> int:
	return version_option.get_selected_id()

func add_to_recent(path: String, vrm_meta: Resource) -> void:
	# Remove if already exists
	for i in range(recent_models.size() - 1, -1, -1):
		if recent_models[i]["path"] == path:
			recent_models.remove_at(i)
	
	var model_data: Dictionary[Variant, Variant] = {
		"path": path,
		"title": path.get_file(),
		"thumb_path": "",
		"version": ""
	}
	
	if vrm_meta:
		var title = vrm_meta.get("title")
		if title and not title.is_empty():
			model_data["title"] = title
			
		var thumb: Texture2D = vrm_meta.get("thumbnail_image")
		if thumb and thumb.get_image():
			var hash_name: String = str(path.hash()) + ".png"
			var thumb_path: String = THUMBNAILS_DIR + hash_name
			thumb.get_image().save_png(thumb_path)
			model_data["thumb_path"] = thumb_path
			
		var spec = vrm_meta.get("spec_version")
		if spec:
			model_data["version"] = "VRM " + str(spec)
			
	recent_models.push_front(model_data)
	
	# Keep only last 20
	if recent_models.size() > 20:
		recent_models.resize(20)
		
	_save_recent_models()
	if visible:
		_refresh_ui()

func _load_recent_models() -> void:
	if FileAccess.file_exists(RECENT_MODELS_FILE):
		var file: FileAccess = FileAccess.open(RECENT_MODELS_FILE, FileAccess.READ)
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Array:
				recent_models = data

func _save_recent_models() -> void:
	var file: FileAccess = FileAccess.open(RECENT_MODELS_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(recent_models, "\t"))

func _populate_bundled_models() -> void:
	bundled_models.clear()
	# Search standard bundled directories
	var search_dirs: Array[Variant] = ["res://samples/character_samples/vrm", "res://models", "res://"]
	for dir in search_dirs:
		if DirAccess.dir_exists_absolute(dir):
			var da: DirAccess = DirAccess.open(dir)
			if da:
				da.list_dir_begin()
				var file_name: String = da.get_next()
				while file_name != "":
					if not da.current_is_dir() and (file_name.ends_with(".vrm") or file_name.ends_with(".vrma")):
						var full_path = dir.path_join(file_name)
						if not bundled_models.has(full_path):
							bundled_models.append(full_path)
					file_name = da.get_next()
	
	_preload_bundled_thumbnails()

func _refresh_ui() -> void:
	# Refresh Recent
	for child in recent_grid.get_children():
		child.queue_free()
		
	if recent_models.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "No recent models."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		recent_grid.add_child(lbl)
	else:
		for data in recent_models:
			var btn: Control = _create_model_card(data["title"], data["path"], data.get("thumb_path", ""), data.get("version", ""))
			recent_grid.add_child(btn)
			
	# Refresh Bundled
	for child in bundled_grid.get_children():
		child.queue_free()
		
	if bundled_models.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "No bundled models found. (Did you mount a Models.pck?)"
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		bundled_grid.add_child(lbl)
	else:
		for path in bundled_models:
			var hash_name: String = str(path.hash()) + ".png"
			var thumb_path: String = THUMBNAILS_DIR + hash_name
			var btn: Control = _create_model_card(path.get_file(), path, thumb_path, "")
			bundled_grid.add_child(btn)

func _preload_bundled_thumbnails() -> void:
	for path in bundled_models:
		var hash_name: String = str(path.hash()) + ".png"
		var thumb_path: String = THUMBNAILS_DIR + hash_name
		if not FileAccess.file_exists(thumb_path):
			var result: Dictionary = VRMLoader.load_vrm_from_res(path, 0)
			if result["success"] and result["node"]:
				var meta = result["node"].get("vrm_meta")
				if meta:
					var thumb: Texture2D = meta.get("thumbnail_image")
					if thumb and thumb.get_image():
						thumb.get_image().save_png(thumb_path)
				result["node"].queue_free()
			await get_tree().process_frame
	if visible:
		_refresh_ui()

func _create_model_card(title: String, path: String, thumb_path: String, version_text: String) -> Control:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(160, 200)
	btn.theme_type_variation = "MenuTabButton" # Using our premium tab style or a custom style
	btn.pressed.connect(func():
		hide()
		model_selected.emit(path)
	)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	btn.add_child(vbox)
	
	var image_container: Control = Control.new()
	image_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_container.custom_minimum_size = Vector2(144, 144)
	
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if thumb_path != "" and FileAccess.file_exists(thumb_path):
		var img: Image = Image.load_from_file(thumb_path)
		if img:
			tex_rect.texture = ImageTexture.create_from_image(img)
	
	if tex_rect.texture == null:
		# Placeholder
		var placeholder: ColorRect = ColorRect.new()
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.color = Color(0.2, 0.2, 0.25)
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.add_child(placeholder)
		var lbl: Label = Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.text = "No Thumb"
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		placeholder.add_child(lbl)
		
	image_container.add_child(tex_rect)
	
	if version_text != "":
		var ver_lbl: Label = Label.new()
		ver_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ver_lbl.text = "  " + version_text + "  "
		ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.6)
		style.corner_radius_bottom_left = 6
		style.corner_radius_top_right = 6
		ver_lbl.add_theme_stylebox_override("normal", style)
		ver_lbl.add_theme_font_size_override("font_size", 12)
		ver_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		ver_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		image_container.add_child(ver_lbl)
		
	vbox.add_child(image_container)
	
	var title_lbl: Label = Label.new()
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.custom_minimum_size = Vector2(144, 40)
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(title_lbl)
	
	return btn
