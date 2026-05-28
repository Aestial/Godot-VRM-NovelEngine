extends Control

const title_scene_name : String = "res://visual-novel/GJDDM/scenes/Title/title_screen.tscn"

var title_scene: PackedScene = preload(title_scene_name)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_credits_quit_pressed() -> void:
	SceneLoader.change_scene_to_packed(title_scene)
