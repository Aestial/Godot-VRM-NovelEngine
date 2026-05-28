extends VBoxContainer

@onready var motion_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/MotionList
@onready var content_panel: PanelContainer = $PanelContainer

var _motion_anim_player: AnimationPlayer = null
var _available_animations: Array = []
var _active_button: Button = null

func _ready() -> void:
	# Clear initial placeholders if any
	for child in motion_list.get_children():
		child.queue_free()

func setup(model: Node3D) -> void:
	# Create a new AnimationPlayer for body motions to avoid conflicting with VRM blendshapes
	_motion_anim_player = AnimationPlayer.new()
	model.add_child(_motion_anim_player)
	_motion_anim_player.owner = model
	
	# Try to find GeneralSkeleton to set it as root
	var skeleton: Skeleton3D = _find_skeleton(model)
	if skeleton:
		_motion_anim_player.root_node = _motion_anim_player.get_path_to(skeleton.get_parent())
	else:
		_motion_anim_player.root_node = _motion_anim_player.get_path_to(model)
		
	# Clear existing buttons
	for child in motion_list.get_children():
		child.queue_free()
	_available_animations.clear()
	_active_button = null
	
	# Load motions library
	var lib = load("res://visual-novel/animations/basic-locomotion_library.res")
	if lib and lib is AnimationLibrary:
		_motion_anim_player.add_animation_library("", lib)
		var anim_list: Array[StringName] = lib.get_animation_list()
		
		if anim_list.is_empty():
			var lbl := Label.new()
			lbl.text = "No Motions Available"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			motion_list.add_child(lbl)
			return
			
		# Create default T-Pose button
		var tpose_btn = _create_motion_button("T-Pose (Default)", "T-Pose")
		var default_btn = tpose_btn
		
		for anim_name in anim_list:
			var btn = _create_motion_button(anim_name, anim_name)
			# Look for idle as default animation
			if anim_name.to_lower().find("idle") != -1 and (default_btn == tpose_btn or default_btn == null):
				default_btn = btn
				
		# Play default animation
		if default_btn:
			_on_button_pressed(default_btn, default_btn.get_meta("anim_name"))
	else:
		var lbl := Label.new()
		lbl.text = "Library not found"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		motion_list.add_child(lbl)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found:
			return found
	return null

func _create_motion_button(display_name: String, anim_name: String) -> Button:
	var btn := Button.new()
	btn.text = display_name
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 32)
	
	# Apply premium flat styling
	var btn_normal := StyleBoxEmpty.new()
	
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	
	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_hover)
	btn.add_theme_stylebox_override("focus", btn_normal)
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.82))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	
	btn.set_meta("anim_name", anim_name)
	btn.pressed.connect(func(): _on_button_pressed(btn, anim_name))
	motion_list.add_child(btn)
	_available_animations.append(anim_name)
	return btn

func _on_button_pressed(btn: Button, anim_name: String) -> void:
	if not _motion_anim_player:
		return
		
	# Update active button visuals
	if _active_button:
		var btn_normal := StyleBoxEmpty.new()
		_active_button.add_theme_stylebox_override("normal", btn_normal)
		_active_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.82))
		
	_active_button = btn
	
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.0, 0.6, 1.0, 0.15)
	active_style.corner_radius_top_left = 6
	active_style.corner_radius_top_right = 6
	active_style.corner_radius_bottom_left = 6
	active_style.corner_radius_bottom_right = 6
	active_style.border_width_left = 2
	active_style.border_color = Color(0.0, 0.75, 1.0)
	
	btn.add_theme_stylebox_override("normal", active_style)
	btn.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	
	if anim_name == "T-Pose":
		_motion_anim_player.stop()
	else:
		_motion_anim_player.play(anim_name)
