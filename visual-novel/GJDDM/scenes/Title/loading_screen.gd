class_name LoadingScreen extends Control

@onready var progress_bar: ProgressBar = $Loading/ProgressBar
var next_scene: String
var can_load: bool = true

func _ready() -> void:
	next_scene = SceneLoader.next_scene
	ResourceLoader.load_threaded_request(next_scene)
	request_ready() #TODO: Verify
	
func _process(_delta: float) -> void:
	var status: Array[Variant] = []
	ResourceLoader.load_threaded_get_status(next_scene, status)
	
	var progress = status[0] * 100
	progress_bar.value = progress
	
	if progress >= 100 and can_load:
		can_load = false
		var packed_scene: Resource = ResourceLoader.load_threaded_get(next_scene)
		if (packed_scene):
			get_tree().change_scene_to_packed(packed_scene)
		else:
			get_tree().change_scene_to_file("res://visual-novel/GJDDM/scenes/Title/title_screen.tscn")