class_name VRMLoader
extends RefCounted

## Utility class to handle runtime loading of VRM models.
## Relies on the V-Sekai godot-vrm plugin's GLTFDocumentExtension.

const VRM0_EXTENSIONS: Array[String] = [
	"res://addons/vrm/vrm_extension.gd"
]

const VRM1_EXTENSIONS: Array[String] = [
	"res://addons/vrm/1.0/VRMC_materials_mtoon.gd",
	"res://addons/vrm/1.0/VRMC_materials_hdr_emissiveMultiplier.gd",
	"res://addons/vrm/1.0/VRMC_springBone.gd",
	"res://addons/vrm/1.0/VRMC_node_constraint.gd",
	"res://addons/vrm/1.0/VRMC_vrm.gd"
]

## Inspects the binary GLTF (GLB) file structure to quickly determine
## if it uses VRM 0.0 or VRM 1.0 extensions in its JSON chunk.
## Returns 0 for VRM 0.0, 1 for VRM 1.0, and -1 if unknown/invalid.
static func check_vrm_version(absolute_file_path: String) -> int:
	var file := FileAccess.open(absolute_file_path, FileAccess.READ)
	if not file:
		return -1
	
	# Check GLB Magic "glTF"
	var magic := file.get_buffer(4).get_string_from_ascii()
	if magic != "glTF":
		return -1
		
	var _version := file.get_32()
	var _length := file.get_32()
	
	var chunk_length := file.get_32()
	var chunk_type := file.get_buffer(4).get_string_from_ascii()
	if chunk_type != "JSON":
		return -1
		
	var json_data := file.get_buffer(chunk_length).get_string_from_utf8()
	
	if "\"VRMC_vrm\"" in json_data:
		return 1
	elif "\"VRM\"" in json_data:
		return 0
		
	return -1

## Loads a .vrm file from the file system at runtime.
## Returns a Dictionary with the following structure:
## { "success": bool, "error_msg": String, "node": Node3D (or null) }
static func load_vrm(absolute_file_path: String, force_version: int = 0) -> Dictionary:
	var result: Dictionary[Variant, Variant] = {
		"success": false,
		"error_msg": "",
		"node": null
	}
	
	if not FileAccess.file_exists(absolute_file_path):
		result["error_msg"] = "File does not exist at path: " + absolute_file_path
		return result

	var vrm_version := check_vrm_version(absolute_file_path)
	if force_version == 1:
		vrm_version = 0
	elif force_version == 2:
		vrm_version = 1
		
	print("VRM Version: ", vrm_version)
	if vrm_version == -1:
		result["error_msg"] = "File is not a valid VRM or GLB file: " + absolute_file_path
		return result

	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	
	# Load and register the correct extensions based on VRM version
	var extensions_to_register: Array[String] = VRM1_EXTENSIONS if vrm_version == 1 else VRM0_EXTENSIONS
	var registered_extensions: Array[GLTFDocumentExtension] = []
	
	for ext_path in extensions_to_register:
		var ext_instance: GLTFDocumentExtension = load(ext_path).new()
		GLTFDocument.register_gltf_document_extension(ext_instance, true)
		registered_extensions.append(ext_instance)
	
	# Keep images in memory for runtime instead of extracting to disk
	state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
	
	state.set_additional_data(&"vrm/head_hiding_method", 0)
	state.set_additional_data(&"vrm/first_person_layers", 2)
	state.set_additional_data(&"vrm/third_person_layers", 4)
#	state.set_additional_data(&"vrm/already_processed", false)
	
	# Parse the file
	var err: int = gltf.append_from_file(absolute_file_path, state)
	if err != OK:
		result["error_msg"] = "Failed to parse GLTF/VRM file. Error code: " + str(err)
		for ext in registered_extensions:
			GLTFDocument.unregister_gltf_document_extension(ext)
		return result
		
	# Generate the node tree
	var vrm_node: Node3D = gltf.generate_scene(state)
	
	# Cleanup registration
	for ext in registered_extensions:
		GLTFDocument.unregister_gltf_document_extension(ext)
	
	if not vrm_node:
		result["error_msg"] = "Failed to generate scene from parsed data."
		return result
	
	# Godot's GLTF importer natively imports models facing backwards (Z+).
	# For convenience, we rotate it to face forwards (Z-).
	vrm_node.rotation.y = PI
	
	result["success"] = true
	result["node"] = vrm_node
	return result
