extends VBoxContainer

@onready var motion_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/MotionOption
@onready var toggle_btn: Button = $ToggleMotionBtn
@onready var content_panel: PanelContainer = $PanelContainer

var is_expanded: bool = true
var _motion_anim_player: AnimationPlayer = null
var _available_animations: Array = []

func _ready() -> void:
	toggle_btn.pressed.connect(_on_toggle_pressed)
	motion_option.item_selected.connect(_on_motion_selected)
	motion_option.add_item("No Motions Available")
	motion_option.disabled = true

func setup(model: Node3D) -> void:
	# Create a new AnimationPlayer for body motions to avoid conflicting with VRM blendshapes
	_motion_anim_player = AnimationPlayer.new()
	model.add_child(_motion_anim_player)
	_motion_anim_player.owner = model
	
	# Try to find GeneralSkeleton to set it as root
	var skeleton = _find_skeleton(model)
	if skeleton:
		_motion_anim_player.root_node = _motion_anim_player.get_path_to(skeleton.get_parent())
	else:
		_motion_anim_player.root_node = _motion_anim_player.get_path_to(model)
		
	motion_option.clear()
	_available_animations.clear()
	
	# TODO Future: Create a way to let the user load animation libraries, look for the best approach.
	# TODO: Select or create the best default animation library for the viewer. Maybe one for each gender?
	# TODO: Loading this way won't work in web export:
	var lib = load("res://visual-novel/animations/female_idle_actions_library.res")
	if lib and lib is AnimationLibrary:
		_motion_anim_player.add_animation_library("", lib)
		var anim_list = lib.get_animation_list()
		
		if anim_list.is_empty():
			motion_option.add_item("No Motions")
			motion_option.disabled = true
			return
			
		motion_option.disabled = false
		motion_option.add_item("T-Pose (Default)")
		_available_animations.append("T-Pose")
		
		var default_index = 0
		var index = 1
		
		for anim_name in anim_list:
			motion_option.add_item(anim_name)
			_available_animations.append(anim_name)
			
			# User preferred default animation with 'idle' in name
			if anim_name.to_lower().find("idle") != -1 and default_index == 0:
				default_index = index
				
			index += 1
			
		# Play default
		if default_index > 0:
			motion_option.select(default_index)
			_on_motion_selected(default_index)
	else:
		motion_option.add_item("Library not found")
		motion_option.disabled = true

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _on_motion_selected(index: int) -> void:
	if not _motion_anim_player:
		return
		
	var anim_name = _available_animations[index]
	if anim_name == "T-Pose":
		_motion_anim_player.stop()
	else:
		_motion_anim_player.play(anim_name)

func _on_toggle_pressed() -> void:
	is_expanded = not is_expanded
	toggle_btn.text = "Hide Motions" if is_expanded else "Show Motions"
	content_panel.visible = is_expanded
