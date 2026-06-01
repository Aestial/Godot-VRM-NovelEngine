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
	
	btn.theme = load("res://samples/vrm_viewer/vrm_viewer_theme.tres")
	btn.theme_type_variation = "ListButton"
	
	btn.set_meta("anim_name", anim_name)
	btn.pressed.connect(func(): _on_button_pressed(btn, anim_name))
	motion_list.add_child(btn)
	_available_animations.append(anim_name)
	return btn

func _on_button_pressed(btn: Button, anim_name: String) -> void:
	if not _motion_anim_player:
		return
		
	if _active_button:
		_active_button.theme_type_variation = "ListButton"
		
	_active_button = btn
	
	btn.theme_type_variation = "ListButtonActive"
	
	if anim_name == "T-Pose":
		_motion_anim_player.stop()
	else:
		_motion_anim_player.play(anim_name)
