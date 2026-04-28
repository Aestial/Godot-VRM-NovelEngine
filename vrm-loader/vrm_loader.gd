class_name VRMLoader
extends RefCounted

## Utility class to handle runtime loading of VRM models.
## Relies on the V-Sekai godot-vrm plugin's GLTFDocumentExtension.

const VRM_EXTENSION_PATH = "res://addons/vrm/vrm_extension.gd"

## Loads a .vrm file from the file system at runtime.
## Returns a Dictionary with the following structure:
## { "success": bool, "error_msg": String, "node": Node3D (or null) }
static func load_vrm(absolute_file_path: String) -> Dictionary:
	var result = {
		"success": false,
		"error_msg": "",
		"node": null
	}
	
	if not FileAccess.file_exists(absolute_file_path):
		result["error_msg"] = "File does not exist at path: " + absolute_file_path
		return result

	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	
	# Load and register the VRM extension
	var vrm_ext: GLTFDocumentExtension = load(VRM_EXTENSION_PATH).new()
	gltf.register_gltf_document_extension(vrm_ext, true)
	
	# Keep images in memory for runtime instead of extracting to disk
	state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
	
	# Parse the file
	var err: int = gltf.append_from_file(absolute_file_path, state)
	if err != OK:
		result["error_msg"] = "Failed to parse GLTF/VRM file. Error code: " + str(err)
		gltf.unregister_gltf_document_extension(vrm_ext)
		return result
		
	# Generate the node tree
	var vrm_node: Node3D = gltf.generate_scene(state)
	
	# Cleanup registration
	gltf.unregister_gltf_document_extension(vrm_ext)
	
	if not vrm_node:
		result["error_msg"] = "Failed to generate scene from parsed data."
		return result
	
	# Godot's GLTF importer natively imports models facing backwards (Z+).
	# For convenience, we rotate it to face forwards (Z-).
	vrm_node.rotation.y = PI
	
	result["success"] = true
	result["node"] = vrm_node
	return result
