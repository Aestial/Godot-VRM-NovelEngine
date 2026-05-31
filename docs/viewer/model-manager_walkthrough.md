# Model Manager & Extended Meta Panel Walkthrough

I have fully implemented the requested features, including the robust and polished Model Manager alongside the comprehensive VRM metadata viewer.

## 1. Model Manager UI (`ui_model_manager.tscn`)

The new Model Manager replaces the raw file picker flow with a much more visually appealing **Gallery Interface**.
- **Layout**: Features a main modal window with tabs for **Recent** and **Bundled** models.
- **Local File Footer**: The bottom footer panel contains the controls to load local VRM files. Based on your feedback, we have swapped the order so the **Browse...** button is on the left and the **Auto Detect / Version** dropdown is on the right.
- **Dynamic Thumbnails**: When a model is loaded, the manager caches its extracted thumbnail as a raw `.png` into `user://thumbnails/` and links it in a lightweight `user://recent_models.json` array. This ensures incredibly fast loads across all platforms (including web/IndexedDB) because it avoids parsing heavy 3D files just to generate gallery icons.
- **Bundled Models**: It automatically scans known directories (`res://models/`, `res://samples/character_samples/vrm/`) for any bundled `.vrm` files.

## 2. Dynamic Thumbnail Button Fix (`vrm_viewer_model_manager.gd`)

We fixed an issue where the thumbnail image/badge inside the model cards would block mouse events, preventing users from clicking the button:
- Added `mouse_filter = Control.MOUSE_FILTER_IGNORE` to all dynamic UI controls instantiated within the card (`VBoxContainer`, `Control`, `TextureRect`, `ColorRect`, `Label`).
- This ensures that click events transparently pass through to the underlying parent `Button`, making the entire card area reactive.

## 3. Viewer Integration (`vrm_viewer.gd`)

The main Viewer script now seamlessly hooks into the new manager:
- The top-left "Load VRM" button is now labeled **Library** and opens the new Model Manager.
- Upon a successful VRM load via any method, the system extracts the `VRMMeta` structure, pulls the thumbnail, and saves the history locally using `_model_manager.add_to_recent(path, meta)`.

## 4. Comprehensive Meta Panel (`vrm_viewer_ui_meta_panel.gd`)

The Meta Panel has been completely rewritten to dynamically render all available properties extracted from Godot-VRM's `vrm_meta.gd` instead of using hardcoded labels. 

The panel cleanly groups information under stylized headers:
- **General Info**: Title, Author, Contact, Version, Reference
- **Permissions**: Allowed User, Violent/Sexual/Commercial Usage, Antisocial/Hate policies, Political/Religious flags
- **Redistribution & License**: Credit requirements, Modifications, License types, Third-party URLs
- **Exporter Info**: VRM Specification Version, Exporter Version

> [!TIP]
> The dynamic generation clears old metadata rows and recreates them, ignoring any blank or null fields to keep the UI perfectly clean!
