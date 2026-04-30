# Runtime VRM Loading Implementation Plan

## 1. The Tool: V-Sekai Godot-VRM
The good news is that the best tool available on the web for this is **already in your project**! 

The [V-Sekai Godot-VRM](https://github.com/V-Sekai/godot-vrm) plugin, which you're using to import VRMs in the editor, fully supports **runtime loading** via Godot's underlying `GLTFDocument` class. Because VRM is based on the glTF format, the plugin provides a `GLTFDocumentExtension` that parses all the VRM-specific metadata (SpringBones, BlendShapes, MToon Shaders) during runtime import.

## 2. Automating the Setup Procedure
To make this a seamless feature for users (e.g., choosing their own `.vrm` file via a File Dialog) and a modular workflow for developers, we need a standard script that handles both the **loading** and the **automatic setup** of the character logic.

Here is an example of what an automated `VRMLoader` class will look like:

```gdscript
class_name VRMLoader
extends Node

## Loads a .vrm file from the file system at runtime and returns the generated Node3D
static func load_vrm_at_runtime(file_path: String) -> Node3D:
	var gltf: GLTFDocument = GLTFDocument.new()
	var vrm_extension: GLTFDocumentExtension = load("res://addons/vrm/vrm_extension.gd").new()
	gltf.register_gltf_document_extension(vrm_extension, true)
	
	var state: GLTFState = GLTFState.new()
	# Handle images in memory for runtime
	state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
	
	var err = gltf.append_from_file(file_path, state)
	if err != OK:
		push_error("Failed to load VRM file: ", file_path)
		gltf.unregister_gltf_document_extension(vrm_extension)
		return null
		
	var generated_scene = gltf.generate_scene(state)
	gltf.unregister_gltf_document_extension(vrm_extension)
	
	return generated_scene

## Automatically attaches all necessary gameplay logic to the freshly loaded VRM model
static func setup_character_puppet(vrm_model: Node3D) -> void:
	# 1. Rotate 180 degrees (VRMs face backward by default in Godot glTF import)
	vrm_model.rotation.y = PI
	
	# 2. Retarget animations: Extract the Skeleton3D and map humanoid bones
	var skeleton: Skeleton3D = vrm_model.find_children("*", "Skeleton3D")[0]
	if skeleton:
		# Map Godot's humanoid retargeting if needed
		pass
		
	# 3. Inject our AnimationTree and AnimationPlayer
	# (We can clone an existing Animation library or load a generic one)
	var anim_player = AnimationPlayer.new()
	# ... load standard animations into anim_player ...
	vrm_model.add_child(anim_player)
	
	var anim_tree = AnimationTree.new()
	# ... configure standard locomotion state machine ...
	vrm_model.add_child(anim_tree)
```

## 3. Architecture Refactoring (The Modular Goal)
For the overarching architecture, instead of trying to attach movement and logic scripts *directly* to the loaded VRM Node3D, we should switch to a **Puppeteer Pattern** (Decoupled Architecture).

**Current Architecture:**
`CharacterBody3D` -> `Visuals` (VRM) -> `AnimationTree` / `State Machine` all tangled together.

**Proposed Decoupled Architecture:**
- **Actor (CharacterBody3D):** Contains collision shape, movement logic, input handling, and generic state machine. It is completely blind to what its visuals look like.
- **Puppet (Node3D):** The runtime-loaded VRM model. It contains the Skeleton, Meshes, SpringBones, and an AnimationPlayer.
- **Workflow:** When the user loads a new `.vrm` file, we instantiate it as a "Puppet", delete the old Puppet, parent the new Puppet to the "Actor", and configure the Actor's `AnimationTree` to point its `anim_player` property to the new Puppet's `AnimationPlayer`.

This pattern entirely separates the *logic* from the *visuals*, making it trivial to swap out VRM avatars at runtime with zero bugs.
