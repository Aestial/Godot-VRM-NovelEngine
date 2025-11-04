class_name QuestCanvasLayer extends CanvasLayer

@export var text_content: String:
	set = _set_text_content,
	get = _get_text_content
	
@export var is_displayed: bool:
	set = _set_is_displayed,
	get = _get_is_displayed

@export var is_completed:= false:
	set = _set_is_completed,
	get = _get_is_completed
	
func _ready() -> void:
	is_displayed = false
	
func _set_is_completed(value: bool) -> void:
	is_completed = value
	is_displayed = false

func _get_is_completed() -> bool:
	return is_completed	
	
func _set_is_displayed(value: bool) -> void:
	is_displayed = value or not is_completed
	visible = value

func _get_is_displayed() -> bool:
	return is_displayed

func _set_text_content(value: String) -> void:
	text_content = value
	$Panel/RichTextLabel.text = text_content
	
func _get_text_content() -> String:
	return text_content
