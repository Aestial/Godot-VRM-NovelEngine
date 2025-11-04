extends Control

@export var timeline_name: String = "chapterA"

func _ready():
	Dialogic.start(timeline_name)
	#pass

func _input(event: InputEvent) -> void:
	#check if a dialog is already running
	if Dialogic.current_timeline != null:
		return
	if event is InputEventKey and event.keycode == KEY_ENTER and event.pressed:
		Dialogic.start(timeline_name)
		get_viewport().set_input_as_handled()
