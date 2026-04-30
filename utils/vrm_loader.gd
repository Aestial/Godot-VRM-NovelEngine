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

## Inspects raw GLB bytes to determine VRM version without needing a file on disk.
## Returns 0 for VRM 0.0, 1 for VRM 1.0, and -1 if unknown/invalid.
static func check_vrm_version_from_buffer(data: PackedByteArray) -> int:
	if data.size() < 20: # Minimum: 12-byte header + 8-byte chunk header
		return -1
	
	# Check GLB Magic "glTF"
	var magic := data.slice(0, 4).get_string_from_ascii()
	if magic != "glTF":
		return -1
	
	# Skip version (4 bytes) and length (4 bytes)
	# Read chunk_length at offset 12 (little-endian u32)
	var chunk_length: int = data.decode_u32(12)
	
	# Check chunk type at offset 16
	var chunk_type := data.slice(16, 20).get_string_from_ascii()
	if chunk_type != "JSON":
		return -1
	
	if data.size() < 20 + chunk_length:
		return -1
	
	var json_data := data.slice(20, 20 + chunk_length).get_string_from_utf8()
	
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
	var registered_extensions := _register_vrm_extensions(vrm_version)
	_configure_gltf_state(state)
	
	# Parse the file
	var err: int = gltf.append_from_file(absolute_file_path, state)
	if err != OK:
		result["error_msg"] = "Failed to parse GLTF/VRM file. Error code: " + str(err)
		_unregister_extensions(registered_extensions)
		return result
	
	return _generate_vrm_scene(gltf, state, registered_extensions)

## Loads a VRM from raw bytes (for web uploads via FileAccessWeb).
## Returns a Dictionary with the same structure as load_vrm().
static func load_vrm_from_buffer(data: PackedByteArray, force_version: int = 0) -> Dictionary:
	var result: Dictionary[Variant, Variant] = {
		"success": false,
		"error_msg": "",
		"node": null
	}
	
	if data.is_empty():
		result["error_msg"] = "Empty data buffer provided."
		return result
	
	var vrm_version := check_vrm_version_from_buffer(data)
	if force_version == 1:
		vrm_version = 0
	elif force_version == 2:
		vrm_version = 1
	
	print("VRM Version (from buffer): ", vrm_version)
	if vrm_version == -1:
		result["error_msg"] = "Buffer is not a valid VRM or GLB file."
		return result
	
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var registered_extensions := _register_vrm_extensions(vrm_version)
	_configure_gltf_state(state)
	
	# Parse from buffer — base_path is empty since the data is self-contained
	var err: int = gltf.append_from_buffer(data, "", state)
	if err != OK:
		result["error_msg"] = "Failed to parse GLTF/VRM buffer. Error code: " + str(err)
		_unregister_extensions(registered_extensions)
		return result
	
	return _generate_vrm_scene(gltf, state, registered_extensions)

## Loads a VRM from a res:// or user:// path by reading bytes into memory first.
## Works on ALL platforms including web exports (unlike load_vrm which uses
## append_from_file and fails on web due to browser filesystem sandboxing).
static func load_vrm_from_res(res_path: String, force_version: int = 0) -> Dictionary:
	var result: Dictionary[Variant, Variant] = {
		"success": false,
		"error_msg": "",
		"node": null
	}
	
	if not FileAccess.file_exists(res_path):
		result["error_msg"] = "File not found at: " + res_path
		return result
	
	var file := FileAccess.open(res_path, FileAccess.READ)
	if not file:
		result["error_msg"] = "Cannot open file: " + res_path + " (error: " + str(FileAccess.get_open_error()) + ")"
		return result
	
	var data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	if data.is_empty():
		result["error_msg"] = "File is empty: " + res_path
		return result
	
	print("[VRMLoader] Loading from res:// via buffer (%d bytes): %s" % [data.size(), res_path])
	return load_vrm_from_buffer(data, force_version)

# ---------- Private helpers ----------

## Registers the appropriate VRM GLTF extensions and returns the list for later cleanup.
static func _register_vrm_extensions(vrm_version: int) -> Array[GLTFDocumentExtension]:
	var extensions_to_register: Array[String] = VRM1_EXTENSIONS if vrm_version == 1 else VRM0_EXTENSIONS
	var registered_extensions: Array[GLTFDocumentExtension] = []
	
	for ext_path in extensions_to_register:
		var ext_instance: GLTFDocumentExtension = load(ext_path).new()
		GLTFDocument.register_gltf_document_extension(ext_instance, true)
		registered_extensions.append(ext_instance)
	
	return registered_extensions

## Configures the GLTFState with VRM-specific settings.
static func _configure_gltf_state(state: GLTFState) -> void:
	# Keep images in memory for runtime instead of extracting to disk
	state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
	
	state.set_additional_data(&"vrm/head_hiding_method", 0)
	state.set_additional_data(&"vrm/first_person_layers", 2)
	state.set_additional_data(&"vrm/third_person_layers", 4)
#	state.set_additional_data(&"vrm/already_processed", false)

## Unregisters previously registered GLTF extensions.
static func _unregister_extensions(extensions: Array[GLTFDocumentExtension]) -> void:
	for ext in extensions:
		GLTFDocument.unregister_gltf_document_extension(ext)

## Generates the final VRM scene from a parsed GLTFDocument + GLTFState.
static func _generate_vrm_scene(gltf: GLTFDocument, state: GLTFState, registered_extensions: Array[GLTFDocumentExtension]) -> Dictionary:
	var result: Dictionary[Variant, Variant] = {
		"success": false,
		"error_msg": "",
		"node": null
	}
	
	# Generate the node tree
	var vrm_node: Node3D = gltf.generate_scene(state)
	
	# Cleanup registration
	_unregister_extensions(registered_extensions)
	
	if not vrm_node:
		result["error_msg"] = "Failed to generate scene from parsed data."
		return result
	
	# Godot's GLTF importer natively imports models facing backwards (Z+).
	# For convenience, we rotate it to face forwards (Z-).
	vrm_node.rotation.y = PI
	
	result["success"] = true
	result["node"] = vrm_node
	return result
