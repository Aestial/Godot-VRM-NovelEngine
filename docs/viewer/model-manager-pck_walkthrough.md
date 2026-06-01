# Bundled Models & PCK System Updates

We have implemented the approved plan to modernize the bundled models view and add robust support for external resource packs (PCKs).

## 1. Grid Layout for Bundled Models (`ui_model_manager.tscn`)

The "Bundled Models" tab now uses the same visually appealing grid layout (`FlowContainer`) as the "Recent Models" tab, replacing the old vertical list.

## 2. Thumbnail Preloading & Caching (`vrm_viewer_model_manager.gd`)

We've introduced a fast and responsive caching system for bundled models:
- When the Model Manager initializes, it calls `_preload_bundled_thumbnails()` to scan bundled directories.
- If a model's thumbnail isn't already cached, it uses `VRMLoader` to extract the metadata, saves the thumbnail as a `.png` in `user://thumbnails/`, and immediately frees the loaded node to avoid memory leaks.
- This process yields to the main thread using `await get_tree().process_frame` between models, ensuring the viewer's UI doesn't freeze.
- `_refresh_ui()` now uses the same premium `_create_model_card()` method for bundled models as it does for recent models.

## 3. PCK Loading Support (`vrm_viewer.gd`)

To support lightweight main executables while allowing massive model libraries, the viewer now supports loading `.pck` files automatically at startup:
- Early in the `_ready()` function, `_try_load_pcks()` searches for `Models.pck` alongside the executable path (`OS.get_executable_path().get_base_dir()`) and in the `user://` directory.
- Using Godot's `ProjectSettings.load_resource_pack()`, the PCK's contents are virtually mounted into the `res://` file system.
- Because this happens *before* the model manager populates its models, any `.vrm` files housed inside the newly loaded PCK under `res://models/` or other scanned paths are instantly detected and integrated seamlessly into the "Bundled Models" tab.
