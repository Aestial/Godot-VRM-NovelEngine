@icon("res://addons/plenticons/icons/16x/creatures/person-red.png")
@tool
class_name NovelCharacter extends CharacterBody3D

enum CharacterType {
	NPC,
	PLAYER
}

@export var character_type: CharacterType = CharacterType.NPC:
	set = _set_character_type,
	get = _get_character_type

@export_category("Dialogic")
@export var dialogic_character: DialogicCharacter
@export var character_timeline: DialogicTimeline
@export var has_monologue: bool

@export_category("VRM")
@export var vrm_scene: PackedScene : set = _set_vrm_scene
@export var current_animation: Animation

@export_category("Pose")
@export var default_pose_name: String = "idle"
@export var default_pose_amount: float = 1.0

@export_category("Override camera")
@export var use_override_camera: bool = false
@export var override_camera: PhantomCamera3D
@export_category("Face Camera")
@export var camera_height_offset: float = -0.1 #Offset from top of hear
@export var face_height_ratio: float = 0.9 # 90% of height for face target 
@export_category("Third Person Camera")
@export var camera_distance: float = 1.0
@export var fov: ThirdPersonCamera.FOV = ThirdPersonCamera.FOV.NORMAL

@export_category("Locomotion")
@export var speed: float = 2.0:
	set(v):
		speed = v
		if (move_action != null):
			move_action.speed = speed
					
@export var jump_strength: float = 4.0:
	set(v):
		jump_strength = v
		if (jump_action != null):
			jump_action.JUMP_STRENGTH = jump_strength		

signal interaction_toggle
signal interaction_area_entered
signal interaction_area_exited

var can_interact: bool
var is_busy: bool

var _can_wake:= true
var _current_animation_player: AnimationPlayer
var _interaction_character: NovelCharacter
var _vrm_model: VRMTopLevel

# Action Nodes
@onready var move_action: ActionNode = $ActionContainer/Move
@onready var jump_action: ActionNode = $ActionContainer/Jump
## Component nodes
# Public
@onready var third_person_camera: ThirdPersonCamera = $ThirdPersonCamera
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var gaze_target: Node3D = $GazeTarget
@onready var interaction_area: Area3D = $CollisionShape3D/InteractionArea3D
@onready var socket: Node3D =  $CollisionShape3D/Socket
# Private
@onready var _animation_tree: CharacterAnimationTree = $AnimationTree
@onready var _portrait_camera: PortraitCamera = $CollisionShape3D/PortraitCamera
@onready var _interaction_hud: InteractionHud = $InteractionHUD
@onready var _model_container: Node3D = $CollisionShape3D/ModelContainer
@onready var _grounded_movement: MovementGroundedComplex = $MovementManager/GroundedMovement # Improve this!


func _validate_property(property: Dictionary) -> void:
	################
	## Player
	################
	if property.name == "has_monologue" and character_type == CharacterType.NPC:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "camera_distance" and character_type == CharacterType.NPC:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "fov" and character_type == CharacterType.NPC:
		property.usage = PROPERTY_USAGE_NO_EDITOR		
	if property.name == "use_override_camera" and character_type == CharacterType.NPC:
		property.usage = PROPERTY_USAGE_NO_EDITOR	
	if property.name == "override_camera" and character_type == CharacterType.NPC:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not dialogic_character:
		warnings.append("DialogicCharacter resource is not assigned")
	if not vrm_scene:
		warnings.append("VRM scene is not assigned")
	if not _animation_tree:
		warnings.append("AnimationTree node is missing - needed for animations")
	return warnings


func _ready() -> void:
	if not _model_container:
		var container = Node3D.new()
		container.name = "ModelContainer"
		collision_shape.add_child(container)
		container.set_owner(get_tree().edited_scene_root)
		
	if vrm_scene:
		_vrm_model = _instantiate_model(vrm_scene)
		_adjust_camera_nodes()
		
	if _animation_tree:
		_animation_tree.set_pose(default_pose_name, default_pose_amount)
	
	if Engine.is_editor_hint():
		return
			
	move_action.speed = speed
	jump_action.jump_strength = jump_strength		
	
	interaction_area.body_entered.connect(_on_interaction_area_3d_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_3d_body_exited)
					
	Dialogic.timeline_ended.connect(_on_dialogic_timeline_ended)
	Dialogic.timeline_started.connect(_on_dialogic_timeline_started)
	
	## TODO: Replace with signal of custom event (Cameras)?
	Dialogic.Text.speaker_updated.connect(_on_dialogic_speaker_updated) # This is working
	# Dialogic.Portraits.character_joined.connect(_on_dialogic_character_joined) # TODO: Use this as reference for Custom Event
	
		
func _unhandled_input(event: InputEvent) -> void:	
	if _can_wake and character_type == CharacterType.PLAYER:	
		_can_wake = false
		reset_camera()
		
	if character_timeline and has_monologue:
		start_dialogue(character_timeline)
		return
	
	if character_type == CharacterType.PLAYER and can_interact and \
			event.is_action_pressed("interact"):
		play_interaction()			
		
func reset_camera() -> void:
	print("Resetting character cameras")
	if _portrait_camera:
		_portrait_camera.set_priority(1)
	if character_type != CharacterType.PLAYER:
		return
	if override_camera: 
		override_camera.set_priority(5 if use_override_camera else 0)
	if not third_person_camera or not third_person_camera.camera:
		return
	third_person_camera.set_length(camera_distance)
	third_person_camera.change_fov(fov)
	third_person_camera.set_priority(2 if use_override_camera else 5)
		
func hide_interaction() -> void:
	can_interact = false
	_interaction_hud.hide()
	
func play_interaction() -> void:
	hide_interaction()
	_stop_movement()
	start_dialogue(_interaction_character.character_timeline)
	
func show_interaction(character: NovelCharacter) -> void:
	if is_busy: 
		return
	_interaction_character = character
	if _interaction_character.character_timeline == null: 
		return
	can_interact = true
	_interaction_hud.display(character.dialogic_character.display_name)
	
func start_dialogue(timeline: DialogicTimeline) -> void:
	if Dialogic.current_timeline != null: return
	Dialogic.start(timeline)
	get_viewport().set_input_as_handled()
							
func _instantiate_model(scene: PackedScene) -> Node3D:
	if not _model_container:
		push_error("ModelContainer is missing!")
		return null
	if not scene:
		push_error("No scene provided to instantiate!")
		return null
	# Clear the current model
	for child in _model_container.get_children():
		child.queue_free()	
	# Instantiate and add the new model
	var new_model = scene.instantiate()
	_model_container.add_child(new_model)
	_connect_animation_player(new_model)
	return new_model
	
func _focus_character() -> void:
	if not _portrait_camera:
		return
	_portrait_camera.set_priority(8)

func _get_character_type() -> CharacterType:
	return character_type
		
func _set_character_type(value: CharacterType) -> void:
	print("Updating character type to " + str(value))
	character_type = value
	notify_property_list_changed()
	
func _stop_movement() -> void:
	_grounded_movement.disable_all_movement() # TODO: not working by itself
	_grounded_movement.exit()

func _play_movement() -> void:
	_grounded_movement.enable_all_movement() # TODO: not working by itself (at all?)
	_grounded_movement.enter()
	
func _set_vrm_scene(value: PackedScene) -> void:
	vrm_scene = value
	_refresh_model()
	
func _refresh_model() -> void:
	if not _model_container or not vrm_scene:
		return
	_vrm_model = _instantiate_model(vrm_scene)		
#	_adjust_camera_nodes()
	# Wait a frame for the model to be fully instantiated
	call_deferred("_adjust_camera_nodes")
	# Make sure it's editable in editor
	_vrm_model.set_owner(get_tree().edited_scene_root)		
		
func _adjust_camera_nodes() -> void:
#	if not Engine.is_editor_hint():
#		return
	var height: float = _calculate_character_height()
	print("Character height: " + str(height))
	if height > 0:
		_update_node_heights(height)
	notify_property_list_changed()
		
func _calculate_character_height() -> float:
	var aabb: AABB = _get_character_aabb()
	if aabb.has_volume():
		return aabb.size.y
	return 0.0

func _get_character_aabb() -> AABB:
	var aabb: AABB
	for mesh in _get_all_mesh_instances():
		var mesh_transform = mesh.global_transform
		var mesh_aabb = mesh.get_aabb()
		mesh_aabb = AABB(mesh_transform * mesh_aabb.position, mesh_aabb.size)
#		print("Mesh name: " + mesh.name + " with volume: " + str(mesh_aabb.get_volume()))
		if aabb.has_volume():
			aabb = aabb.merge(mesh_aabb)
		else:
			aabb = mesh_aabb
	return aabb

func _get_all_mesh_instances() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child in _model_container.get_children():
		if child.name == _vrm_model.name: # Taking both characters: new and old, need to filter.
			_collect_mesh_instances(child, meshes)
	return meshes

func _collect_mesh_instances(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, meshes)

func _update_node_heights(height: float) -> void:
	# Top of head + small offset
	var adjusted_height = height + camera_height_offset
	# Adjusted height to face ratio
	var face_height = adjusted_height * face_height_ratio
	# Adjust camera pivots 
	if third_person_camera:
		third_person_camera.position.y = adjusted_height 
	# Child of CollisionShape
	if _portrait_camera:
		_portrait_camera.position.y = face_height - collision_shape.position.y
	# Adjust face target (e.g., for dialogic look-at)
	if gaze_target:
		gaze_target.position.y = face_height

		
func _connect_animation_player(model_node: Node) -> void:
	# Find AnimationPlayer in the VRM model
	var animation_player: AnimationPlayer = _find_animation_player(model_node)	
	if animation_player and _animation_tree:
		_current_animation_player = animation_player
		_animation_tree.anim_player = _animation_tree.get_path_to(animation_player)
#		print("AnimationPlayer connected to AnimationTree: ", animation_player.name)
	elif _animation_tree:
		push_warning("No AnimationPlayer found in VRM model for AnimationTree")

func _find_animation_player(node: Node) -> AnimationPlayer:
	# Recursively search for AnimationPlayer
	if node is AnimationPlayer:
		return node as AnimationPlayer	
	for child in node.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result:
			return result	
	return null
	
#func _on_dialogic_character_joined(info: Dictionary) -> void:
#	print("Timeline character joined")
#	print(info)
	
func _on_dialogic_speaker_updated(new_character: DialogicCharacter) -> void:
	if new_character == null: return
#	print("Speaker updated: " + new_character.display_name + ":" + character.display_name)
	if new_character == dialogic_character:
#		print("Focusing on: " + new_character.display_name)
		_focus_character()
		
func _on_dialogic_timeline_ended() -> void:
	is_busy = false
	_animation_tree.reset()
	_play_movement()
	reset_camera()
	interaction_toggle.emit(false)
	
func _on_dialogic_timeline_started() -> void:
	is_busy = true
	_animation_tree.reset()
	_stop_movement()
	
	if character_type == CharacterType.NPC or has_monologue:
		return
	_move_to_socket()
	interaction_toggle.emit(true)
	
func _on_interaction_area_3d_body_entered(body: Node3D) -> void:
	if is_busy or character_type == CharacterType.PLAYER or \
			body == self or body is not NovelCharacter or \
			not body.character_type == CharacterType.PLAYER: 
		return
	if not character_timeline: 
		print_rich("[color=yellow]No timeline loaded to NPC")
		return
	print("Player entered NPC space")
	_stop_movement()
	_animation_tree.reset() # TODO: Improve
	body.show_interaction(self)
	interaction_area_entered.emit(body as NovelCharacter)

func _on_interaction_area_3d_body_exited(body: Node3D) -> void:
	if is_busy or character_type == CharacterType.PLAYER or \
			body == self or body is not NovelCharacter or \
			not body.character_type == CharacterType.PLAYER:
		return
	print("Player exited NPC space")
	_play_movement()
	_animation_tree.reset() # TODO: Improve
	body.hide_interaction() ## TODO: DEBOUNCE!
	interaction_area_exited.emit(body as NovelCharacter)

func _move_to_socket():
	var target_socket: Node3D = _interaction_character.socket
	## Root global_position
	global_position = target_socket.global_position
	var target_euler: Vector3 = Vector3(
		target_socket.global_rotation.x, 
		target_socket.global_rotation.y + deg_to_rad(180), 
		target_socket.global_rotation.z)
	print(target_euler)
	## CollisionShape global_rotation
	collision_shape.global_rotation = target_euler
