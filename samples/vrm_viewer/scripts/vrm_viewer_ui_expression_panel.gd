extends VBoxContainer

@onready var expression_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ExpressionList
@onready var content_panel: PanelContainer = $PanelContainer

var _anim_player: AnimationPlayer = null
var _available_animations: Array = []
var _active_button: Button = null

func _ready() -> void:
	# Clear initial placeholders if any
	for child in expression_list.get_children():
		child.queue_free()

func setup(model: Node3D) -> void:
	_anim_player = _find_animation_player(model)
	
	# Clear existing buttons
	for child in expression_list.get_children():
		child.queue_free()
	_available_animations.clear()
	_active_button = null
	
	if not _anim_player:
		var lbl := Label.new()
		lbl.text = "No Expressions Available"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		expression_list.add_child(lbl)
		return
	
	var anim_list: PackedStringArray = _anim_player.get_animation_list()
	if anim_list.is_empty():
		var lbl := Label.new()
		lbl.text = "No Expressions Available"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		expression_list.add_child(lbl)
		return
	
	# Create neutral expression button (default state)
	var neutral_btn = _create_expression_button("Neutral")
	
	# Automatically select Neutral first
	if neutral_btn:
		_on_button_pressed(neutral_btn, "Neutral")
	
	for anim_name in anim_list:
		if anim_name == "RESET":
			continue
		_create_expression_button(anim_name)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found:
			return found
	return null

func _create_expression_button(anim_name: String) -> Button:
	var btn := Button.new()
	btn.text = anim_name
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 32)
	
	btn.theme = load("res://samples/vrm_viewer/vrm_viewer_theme.tres")
	btn.theme_type_variation = "ListButton"
	
	btn.pressed.connect(func(): _on_button_pressed(btn, anim_name))
	expression_list.add_child(btn)
	_available_animations.append(anim_name)
	return btn

func _on_button_pressed(btn: Button, anim_name: String) -> void:
	if not _anim_player:
		return
		
	if _active_button:
		_active_button.theme_type_variation = "ListButton"
		
	_active_button = btn
	
	btn.theme_type_variation = "ListButtonActive"
	
	if _anim_player.has_animation("RESET"):
		_anim_player.play("RESET")
		
	if anim_name != "Neutral" and _anim_player.has_animation(anim_name):
		_anim_player.stop()
		if _anim_player.has_animation("RESET"):
			_anim_player.play("RESET")
			_anim_player.advance(0)
		_anim_player.play(anim_name)
