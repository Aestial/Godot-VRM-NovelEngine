extends Node3D

@onready var camera: Camera3D = $Camera3D
@export var target_model_pivot: Node3D

var is_dragging: bool = false
var last_mouse_pos: Vector2
var zoom_level: float = 1.0
var min_zoom: float = 0.2
var max_zoom: float = 5.0
var zoom_speed: float = 0.2
var pan_speed: float = 0.005
var is_panning: bool = false

func _ready() -> void:
	_update_camera_zoom()

func reset_camera() -> void:
	zoom_level = 1.0
	_update_camera_zoom()
	position = Vector3(0, 1.5, 0)
	rotation = Vector3.ZERO
	if target_model_pivot:
		target_model_pivot.rotation = Vector3(0, PI, 0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_panning = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_level = clamp(zoom_level - zoom_speed, min_zoom, max_zoom)
			_update_camera_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_level = clamp(zoom_level + zoom_speed, min_zoom, max_zoom)
			_update_camera_zoom()
			
	elif event is InputEventMouseMotion:
		if is_dragging and target_model_pivot:
			var delta: Vector2 = event.position - last_mouse_pos
			target_model_pivot.rotate_y(delta.x * 0.01)
			
			var new_rot_x = rotation.x - (delta.y * 0.01)
			rotation.x = clamp(new_rot_x, -PI / 2.5, PI / 2.5)
			
			last_mouse_pos = event.position
		elif is_panning:
			var delta: Vector2 = event.position - last_mouse_pos
			position.x -= delta.x * pan_speed
			position.y += delta.y * pan_speed
			last_mouse_pos = event.position

func _update_camera_zoom() -> void:
	camera.position.z = zoom_level
