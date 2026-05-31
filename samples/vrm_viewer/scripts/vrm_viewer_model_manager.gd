extends Control

signal model_selected(path: String)
signal browse_local_requested()

@onready var recent_grid: FlowContainer = $PanelContainer/MarginContainer/VBoxContainer/Columns/Recent/ScrollContainer/GridContainer
@onready var bundled_grid: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/Columns/Bundled/ScrollContainer/GridContainer

@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var browse_button: Button = $PanelContainer/MarginContainer/VBoxContainer/FooterRow/BrowseButton
@onready var version_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/FooterRow/VersionOption

var RECENT_MODELS_FILE = "user://recent_models.json"
var THUMBNAILS_DIR = "user://thumbnails/"

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
	
	var model_data = {
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
			var hash_name = str(path.hash()) + ".png"
			var thumb_path = THUMBNAILS_DIR + hash_name
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
		var file = FileAccess.open(RECENT_MODELS_FILE, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Array:
				recent_models = data

func _save_recent_models() -> void:
	var file = FileAccess.open(RECENT_MODELS_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(recent_models, "\t"))

func _populate_bundled_models() -> void:
	bundled_models.clear()
	# Search standard bundled directories
	var search_dirs = ["res://samples/character_samples/vrm", "res://models", "res://"]
	for dir in search_dirs:
		if DirAccess.dir_exists_absolute(dir):
			var da = DirAccess.open(dir)
			if da:
				da.list_dir_begin()
				var file_name = da.get_next()
				while file_name != "":
					if not da.current_is_dir() and (file_name.ends_with(".vrm") or file_name.ends_with(".vrma")):
						var full_path = dir.path_join(file_name)
						if not bundled_models.has(full_path):
							bundled_models.append(full_path)
					file_name = da.get_next()

func _refresh_ui() -> void:
	# Refresh Recent
	for child in recent_grid.get_children():
		child.queue_free()
		
	if recent_models.is_empty():
		var lbl = Label.new()
		lbl.text = "No recent models."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		recent_grid.add_child(lbl)
	else:
		for data in recent_models:
			var btn = _create_model_card(data["title"], data["path"], data.get("thumb_path", ""), data.get("version", ""))
			recent_grid.add_child(btn)
			
	# Refresh Bundled
	for child in bundled_grid.get_children():
		child.queue_free()
		
	if bundled_models.is_empty():
		var lbl = Label.new()
		lbl.text = "No bundled models found. (Did you mount a Models.pck?)"
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		bundled_grid.add_child(lbl)
	else:
		for path in bundled_models:
			var btn = _create_bundled_card(path.get_file(), path)
			bundled_grid.add_child(btn)

func _create_bundled_card(title: String, path: String) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 40)
	btn.text = title
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.theme_type_variation = "ListButton"
	btn.pressed.connect(func():
		hide()
		model_selected.emit(path)
	)
	return btn

func _create_model_card(title: String, path: String, thumb_path: String, version_text: String) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(160, 200)
	btn.theme_type_variation = "MenuTabButton" # Using our premium tab style or a custom style
	btn.pressed.connect(func():
		hide()
		model_selected.emit(path)
	)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	btn.add_child(vbox)
	
	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(144, 144)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if thumb_path != "" and FileAccess.file_exists(thumb_path):
		var img = Image.load_from_file(thumb_path)
		if img:
			tex_rect.texture = ImageTexture.create_from_image(img)
	
	if tex_rect.texture == null:
		# Placeholder
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.2, 0.2, 0.25)
		placeholder.custom_minimum_size = Vector2(144, 144)
		tex_rect.add_child(placeholder)
		var lbl = Label.new()
		lbl.text = "No Thumb"
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		placeholder.add_child(lbl)
		
	vbox.add_child(tex_rect)
	
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.custom_minimum_size = Vector2(144, 40)
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(title_lbl)
	
	if version_text != "":
		var ver_lbl = Label.new()
		ver_lbl.text = version_text
		ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ver_lbl.add_theme_font_size_override("font_size", 11)
		ver_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		vbox.add_child(ver_lbl)
	
	return btn
