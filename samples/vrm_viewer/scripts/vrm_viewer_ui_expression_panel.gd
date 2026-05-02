extends VBoxContainer

@onready var expression_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/ExpressionOption
@onready var toggle_btn: Button = $ToggleExpressionBtn
@onready var content_panel: PanelContainer = $PanelContainer

var is_expanded: bool = true
var _anim_player: AnimationPlayer = null
var _available_animations: Array = []

func _ready() -> void:
	toggle_btn.pressed.connect(_on_toggle_pressed)
	expression_option.item_selected.connect(_on_expression_selected)
	expression_option.add_item("No Expressions Available")
	expression_option.disabled = true

func setup(model: Node3D) -> void:
	_anim_player = _find_animation_player(model)
	
	expression_option.clear()
	_available_animations.clear()
	
	if not _anim_player:
		expression_option.add_item("No Expressions")
		expression_option.disabled = true
		return
	
	var anim_list = _anim_player.get_animation_list()
	if anim_list.is_empty():
		expression_option.add_item("No Expressions")
		expression_option.disabled = true
		return
	
	expression_option.disabled = false
	
	# Add a "Neutral" or "None" option if it's not present 
	expression_option.add_item("Neutral")
	_available_animations.append("Neutral")
	# TODO: Check if Neutral is duplicated, then rename it to "None"
	
	for anim_name in anim_list:
		if anim_name == "RESET":
			continue
		expression_option.add_item(anim_name)
		_available_animations.append(anim_name)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _on_expression_selected(index: int) -> void:
	if not _anim_player:
		return
		
	var anim_name = _available_animations[index]
	
	if _anim_player.has_animation("RESET"):
		_anim_player.play("RESET")
		
	if anim_name != "Neutral" and _anim_player.has_animation(anim_name):
		# We use queue to play it right after RESET or just play it if we want it immediately
		# Using advance(0) or just play without blend could work, but triggering RESET
		# usually resets all blendshapes to 0, then we apply the new one.
		_anim_player.stop()
		if _anim_player.has_animation("RESET"):
			_anim_player.play("RESET")
			_anim_player.advance(0)
		_anim_player.play(anim_name)

func _on_toggle_pressed() -> void:
	is_expanded = not is_expanded
	toggle_btn.text = "Hide Expressions" if is_expanded else "Show Expressions"
	
	# Instead of tweening height which can be tricky with VBoxContainer resizing, 
	# we can just show/hide the panel container.
	content_panel.visible = is_expanded
