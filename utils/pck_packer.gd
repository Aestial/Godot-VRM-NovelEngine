@tool
extends EditorScript
## PCK Packer Tool - Creates a Models.pck containing raw VRM files.
##
## HOW TO USE:
## 1. Open this script in the Godot Script Editor.
## 2. Go to File > Run (or Ctrl+Shift+X).
## 3. A "Models.pck" file will be created in your project root.
## 4. Copy Models.pck next to your exported executable:
##    - Linux: place beside vrm_viewer.x86_64
##    - Windows: place beside vrm_viewer.exe
##    - Web: place beside index.html (requires HTTP download logic)
##
## WHY THIS IS NEEDED:
## Godot's export pipeline imports .vrm files via the VRM addon's EditorImportPlugin,
## converting them to .scn (PackedScene). The raw GLB bytes are lost.
## VRMLoader.load_vrm_from_res() needs the raw .vrm bytes to parse at runtime.
## PCKPacker bypasses the import pipeline and packs files as raw bytes.

func _run() -> void:
	print("=== PCK Packer Tool ===")
	
	# Directories to scan for VRM files to bundle
	var vrm_dirs: Array[String] = [
		"res://samples/character_samples/vrm",
		"res://visual-novel/GJDDM/characters/vrm",
		"res://models",
		"res://samples/vrm_samples",
	]
	
	var vrm_files: Array[String] = []
	
	for dir_path in vrm_dirs:
		if DirAccess.dir_exists_absolute(dir_path):
			var da := DirAccess.open(dir_path)
			if da:
				da.list_dir_begin()
				var file_name := da.get_next()
				while file_name != "":
					if not da.current_is_dir() and (file_name.ends_with(".vrm") or file_name.ends_with(".vrma")):
						vrm_files.append(dir_path.path_join(file_name))
					file_name = da.get_next()
	
	if vrm_files.is_empty():
		print("ERROR: No .vrm files found in directories: ", vrm_dirs)
		print("Add your VRM files to one of these directories and try again.")
		return
	
	print("Found ", vrm_files.size(), " VRM file(s):")
	for f in vrm_files:
		print("  - ", f)
	
	# Create PCK
	var packer := PCKPacker.new()
	var output_path := "res://Models.pck"
	var err := packer.pck_start(output_path)
	if err != OK:
		print("ERROR: Failed to start PCK packing: ", err)
		return
	
	for vrm_path in vrm_files:
		# Read raw bytes from disk (not from import cache)
		var file := FileAccess.open(vrm_path, FileAccess.READ)
		if file:
			# The internal path in the PCK matches the res:// path
			err = packer.add_file(vrm_path, vrm_path)
			if err != OK:
				print("  WARNING: Failed to add ", vrm_path, " error: ", err)
			else:
				print("  Packed: ", vrm_path)
		else:
			print("  WARNING: Could not open ", vrm_path)
	
	err = packer.flush()
	if err != OK:
		print("ERROR: Failed to flush PCK: ", err)
		return
	
	var abs_path := ProjectSettings.globalize_path(output_path)
	print("")
	print("SUCCESS! Models.pck created at: ", abs_path)
	print("")
	print("Next steps:")
	print("  1. Export your project (Linux, Windows, or Web)")
	print("  2. Copy Models.pck next to the exported executable")
	print("  3. Run the export — models will appear in the Bundled Models tab!")
