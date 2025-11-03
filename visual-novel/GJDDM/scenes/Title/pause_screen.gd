class_name PauseScreen extends CanvasLayer

@export var menu_scene_name: StringName = "res://visual-novel/GJDDM/scenes/Title/title_screen.tscn"

signal pause_toggle
signal restarted

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var options_screen: CanvasLayer

func _ready() -> void:
	audio_player.stop()
	get_tree().paused = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void: 
	if event.is_action_pressed("pause"):
		_toggle_pause()
	
func _toggle_pause() -> void:
	var is_paused: bool = not get_tree().paused
	if is_paused:
		animation_player.play("pause_start")
		audio_player.play()
		Dialogic.Text.hide_textbox()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Dialogic.Text.show_textbox()
		audio_player.stop()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	visible = is_paused
	Dialogic.paused = is_paused
	pause_toggle.emit(is_paused)
	get_tree().paused = is_paused


func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_options_pressed() -> void:
	options_screen.visible = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	restarted.emit()
	get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	get_tree().paused = false
	SceneLoader.change_scene_to(menu_scene_name)