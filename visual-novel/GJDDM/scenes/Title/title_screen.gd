extends Control

@export var can_play: bool = true

#@export var first_scene_name : StringName = "res://visual-novel/GJDDM/scenes/Metro/Metro.tscn"
#@export var maze_scene_name : StringName = "res://visual-novel/GJDDM/scenes/Laberinto/PrimerLaberinto.tscn"
const first_scene_name : String = "res://visual-novel/GJDDM/scenes/Welcome/Welcome.tscn"
const maze_scene_name : String = "res://visual-novel/GJDDM/scenes/Laberinto/PrimerLaberinto.tscn"

#@export var first_scene: PackedScene
#@export var maze_scene: PackedScene 

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var credits_screem: Control = $Credits

var first_scene: PackedScene = preload(first_scene_name)
var maze_scene: PackedScene = preload(maze_scene_name)

var is_playing: bool = false

func _input(event: InputEvent) -> void:
	if is_playing or not can_play:
		return
#	if InputEventMouseMotion: 
#		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		animation_player.play("title_start")
		can_play = false

func _on_start_pressed() -> void:
#	SceneLoader.change_scene_to(first_scene_name)
	SceneLoader.change_scene_to_packed(first_scene)

func _on_maze_pressed() -> void:
#	SceneLoader.change_scene_to(maze_scene_name)
	SceneLoader.change_scene_to_packed(maze_scene)
	
func _on_credits_pressed() -> void:
	credits_screem.visible = true
