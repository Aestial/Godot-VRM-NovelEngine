extends Node3D

@export var next_scene: PackedScene
@export var character: NovelCharacter

const dialogic_var: String = "welcome_monologue" 

func _ready() -> void:
	Dialogic.timeline_ended.connect(_on_dialogic_timeline_ended)
	Dialogic.timeline_started.connect(_on_dialogic_timeline_started)
#	character.play_monologue()
	
func _on_dialogic_timeline_ended() -> void:
	if not Dialogic.VAR.get_variable(dialogic_var):
		return
	call_deferred("_deferred_change_scene")
	
func _deferred_change_scene() -> void:
	SceneLoader.change_scene_to_packed(next_scene)
	
func _on_dialogic_timeline_started() -> void:
	pass
	
func _on_pause_canvas_layer_pause_toggle(value: bool) -> void:
	Dialogic.paused = value
