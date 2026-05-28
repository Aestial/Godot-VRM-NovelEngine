# VRM-NovelEngine Project Analysis

This document provides a "big picture" overview of the `mask-on-wheelz` (VRM-NovelEngine) project to help you understand its current state and prepare for writing comprehensive documentation.

## 1. Project Overview

**VRM-NovelEngine** is an interactive Visual Novel engine built in **Godot 4.x** (configured for gl_compatibility / Forward Plus). It leverages **Dialogic** for its narrative branching and dialogue systems and relies on **VRM** 3D models for its characters. The project unifies a template scene for the player and NPCs, introducing custom Dialogic events to trigger 3D character animations and expressions.

## 2. Repository & Branch State

### Git Branches
- **Current Branch**: `feature/initial-pose`
- **Other Branches**: 
  - `main`
  - `feature/lip-sync`
  - `feature/quest-system`

### Recent Commits (HEAD)
- `80e2736`: Add Brayan and errand Characters to Metro.tscn
- `1f47075`: Add initial pose and dancing animation to characters. Copy character controller samples scripts.
- `f2fc622`: Move examples from addons to `./samples/` (from `feature/lip-sync`)

### Uncommitted Changes
There are several unstaged changes currently in the working directory:
- **Modified**: Scene updates in `visual-novel/GJDDM/scenes/` (Metro, Laberinto, Title), animation tweaks (`basic-locomotion`, `face-emotions`, `novel-character_blendtree`), and updates to the core `novel_character.gd` script. Project settings (`project.godot`) and dialogic styles have also been modified.
- **Untracked**: A newly added `asset_placer` addon, and character sample assets (Manitas) under `samples/`.

## 3. Project Structure

The repository is modularized primarily between Godot's standard `addons` and the custom `visual-novel` logic directory:

- **`/addons/`**: Third-party and Godot ecosystem tools.
  - Includes: `dialogic`, `vrm` (V-Sekai), `phantom_camera`, `orbit_camera`, `signal_lens`, `asset_placer`, `Godot-MToon-Shader`, `timchi_maze_generation`, `plenticons`.
- **`/dialogic/`**: Narrative definitions. Contains characters (`.dch`), timelines (`.dtl`), and styling (`.tres`) for the visual novel aspects.
- **`/samples/`**: Sample `.glb` characters (e.g., Manitas) and packed test scenes.
- **`/visual-novel/`**: The core application logic and assets.
  - **`/GJDDM/`**: Specific game scenes and assets (Title screen, Metro, Laberinto, fonts, music, etc.). The entry point `title_screen.tscn` is located here.
  - **`/animations/`**: Reusable blend trees, blend spaces, and statemachines for characters.
  - **`/canvas/`**: UI Overlays (like Quest HUDs).
  - **`/characters/`**: Reusable `.tscn` templates for characters (e.g., `novel_character_base.tscn`, `_characters_prototype.tscn`).
  - **`/scenarios/`**: Base level layouts and prototypes (e.g., `_scenario_prototype.tscn`, `_scenario_gridmap.tscn`).
  - **`/scripts/`**: Core logic layer (details below).

## 4. Architecture & Key Classes

The logic in `/visual-novel/scripts/` is divided into functional modules:

### Globals (Autoloads)
- **`SceneLoader`**: Handles asynchronous or smooth transitions between game scenarios.
- **`CinematicManager`**: Manages cutscenes and potentially interacts with Dialogic triggers.
- *(Also injected via addons: `Dialogic`, `PhantomCameraManager`, `SignalLens`)*

### Character System (`/scripts/character/`)
- **`novel_character.gd`**: The fundamental character class. It acts as the backbone for linking the VRM skeleton to animations and movement.
- **`character_animation_tree.gd`**: Handles the logic for interacting with Godot's `AnimationTree` (blending locomotion, expressions, and initial poses).
- **Movement Strategy Scripts**: Separate scripts handle physics and navigation, such as `movement_grounded_complex.gd` and `movement_flight_simple.gd`.

### Controllers (`/scripts/controllers/`)
These act as the "brain" for the character class.
- **Player Controllers**: `controller_player.gd`, `controller_player_third_person.gd` (process input mappings for the user).
- **AI Controllers**: `controller_ai.gd`, `controller_ai_third_person.gd` (handle NPC logic, pathfinding, and idle behaviors).

### Actions (`/scripts/actions/`)
- Contains Area3D based logic for scene interactions: `next_scene_area.gd`, `area_control_message.gd`, `pointer_capture.gd`. This enables the player to trigger dialogues or move between maps.

## 5. General Functionality & Workflow

1. **3D Interactive Narrative**: The user controls a 3D avatar (via `novel_character` + `controller_player_third_person`) in an environment. Approaching specific areas or NPCs triggers Dialogic timelines.
2. **VRM Integration**: 3D character models are imported as VRM files, retargeted using a `HumanoidBoneMap`, and inherited from base scenes to apply standard AnimationLibraries. This allows any standard VTuber model to be dropped directly into the game.
3. **Camera & Presentation**: Utilizes `PhantomCamera` for dynamic, cinematic angles during dialogue scenes or regular gameplay, managed by the `CinematicManager`.
4. **Current Focus**: Based on the active branches and recent commits, the current development focus is on:
   - Polishing initial character posing and idle/dancing animations.
   - Setting up different scenarios (Metro, Laberinto).
   - Establishing a Quest System.
   - Investigating a unified Lip Sync system based on Dialogic Voice events and MP3 audio track analysis.
