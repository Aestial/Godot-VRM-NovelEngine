# Models.pck — How It Works and How to Fix It

## The Problem

When you export a project in Godot, **all imported files go through Godot's import pipeline**. The VRM addon registers an `EditorImportPlugin` that converts `.vrm` files into Godot `PackedScene` (`.scn`) resources:

```
archlinux-chan_v0.1.1.vrm  →  (import)  →  archlinux-chan_v0.1.1.vrm-ce925...scn
```

This means when you export your project (or export a separate PCK using the export dialog), the raw `.vrm` bytes are **replaced** by the imported `.scn` binary. When your `VRMLoader.load_vrm_from_res()` then tries to:

```gdscript
var file := FileAccess.open(res_path, FileAccess.READ)
var data: PackedByteArray = file.get_buffer(file.get_length())
```

...it reads the `.scn` bytes instead of the raw GLB bytes. The GLB magic check (`"glTF"`) fails, and model loading silently fails.

> [!IMPORTANT]
> This is why it **works in the Editor** (reads real files from disk) but **fails in exports** (reads from PCK which contains imported resources).

## The Solution

Use `PCKPacker` to create `Models.pck` with the **raw** `.vrm` files, completely bypassing Godot's import pipeline.

### Created: [pck_packer.gd](file:///home/dorito/Developer/Godot-Projects/Godot-VRM-NovelEngine/utils/pck_packer.gd)

A tool script that scans `res://samples/character_samples/vrm` and `res://models` for `.vrm` files and packs them into `Models.pck` using `PCKPacker`.

### Step-by-Step Usage

1. **Open** `res://utils/pck_packer.gd` in the Godot Script Editor
2. **Run it**: `File → Run` (or `Ctrl+Shift+X`)
3. A `Models.pck` file appears in your **project root** directory
4. **Export** your project normally (Linux or Web)
5. **Copy** `Models.pck` next to the exported executable:
   - Linux: beside `vrm_viewer.x86_64`
   - Web: beside `index.html` *(requires additional HTTP download logic for web)*
6. **Launch** the exported build — bundled models should now appear!

### Debug Logging

Added `[PCK]` and `[ModelManager]` debug prints to both [vrm_viewer.gd](file:///home/dorito/Developer/Godot-Projects/Godot-VRM-NovelEngine/samples/vrm_viewer/scripts/vrm_viewer.gd#L51-L72) and [vrm_viewer_model_manager.gd](file:///home/dorito/Developer/Godot-Projects/Godot-VRM-NovelEngine/samples/vrm_viewer/scripts/vrm_viewer_model_manager.gd#L90-L110). When you run the Linux export, check the terminal output for lines like:

```
[PCK] Executable dir: /path/to/builds
[PCK] Looking for: /path/to/builds/Models.pck
[PCK] File exists: true
[PCK] load_resource_pack result: true
[ModelManager] Scanning dir: res://samples/character_samples/vrm exists: true
[ModelManager] Found: res://samples/character_samples/vrm/archlinux-chan_v0.1.1.vrm
[ModelManager] Total bundled models: 3
```

If you see `File exists: false`, the PCK isn't in the right place. If `load_resource_pack result: false`, the PCK is corrupted. If `Total bundled models: 0`, the internal paths don't match the scan directories.

## Files Changed

| File | Change |
|------|--------|
| [vrm_viewer.gd](file:///home/dorito/Developer/Godot-Projects/Godot-VRM-NovelEngine/samples/vrm_viewer/scripts/vrm_viewer.gd) | Added `[PCK]` debug logging |
| [vrm_viewer_model_manager.gd](file:///home/dorito/Developer/Godot-Projects/Godot-VRM-NovelEngine/samples/vrm_viewer/scripts/vrm_viewer_model_manager.gd) | Added `[ModelManager]` debug logging |
| [pck_packer.gd](file:///home/dorito/Developer/Godot-Projects/Godot-VRM-NovelEngine/utils/pck_packer.gd) | **[NEW]** PCKPacker tool script |
