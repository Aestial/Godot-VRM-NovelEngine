extends VBoxContainer

@onready var light_node: DirectionalLight3D = $"../../../DirectionalLight3D"
@onready var world_environment: WorldEnvironment = $"../../../WorldEnvironment"
@onready var ground_plane: MeshInstance3D = $"../../../GroundPlane"

@onready var light_rot_x_slider: HSlider = $EnvPanel/Scroll/Margin/VBox/LightRotXSlider
@onready var light_rotation_slider: HSlider = $EnvPanel/Scroll/Margin/VBox/LightRotSlider
@onready var light_energy_slider: HSlider = $EnvPanel/Scroll/Margin/VBox/LightEnergySlider
@onready var light_color_picker: ColorPickerButton = $EnvPanel/Scroll/Margin/VBox/LightColorPicker
@onready var sky_energy_slider: HSlider = $EnvPanel/Scroll/Margin/VBox/SkyEnergySlider
@onready var sky_top_color_picker: ColorPickerButton = $EnvPanel/Scroll/Margin/VBox/SkyTopColorPicker
@onready var sky_horizon_color_picker: ColorPickerButton = $EnvPanel/Scroll/Margin/VBox/SkyHorizonColorPicker
@onready var toggle_ground_btn: CheckButton = $EnvPanel/Scroll/Margin/VBox/ToggleGroundBtn
@onready var toggle_env_btn: Button = $ToggleEnvButton
@onready var env_panel: PanelContainer = $EnvPanel

var is_expanded: bool = true
var expanded_size: float = 400.0

func _ready() -> void:
	light_rot_x_slider.value_changed.connect(_on_light_rot_x_changed)
	light_rotation_slider.value_changed.connect(_on_light_rot_changed)
	light_energy_slider.value_changed.connect(_on_light_energy_changed)
	light_color_picker.color_changed.connect(_on_light_color_changed)
	sky_energy_slider.value_changed.connect(_on_sky_energy_changed)
	sky_top_color_picker.color_changed.connect(_on_sky_top_color_changed)
	sky_horizon_color_picker.color_changed.connect(_on_sky_horizon_color_changed)
	toggle_ground_btn.toggled.connect(_on_ground_toggled)
	toggle_env_btn.pressed.connect(_on_toggle_env_pressed)
	
	if light_node:
		light_energy_slider.value = light_node.light_energy
		light_rotation_slider.value = rad_to_deg(light_node.rotation.y)
		light_rot_x_slider.value = rad_to_deg(light_node.rotation.x)
		light_color_picker.color = light_node.light_color
		
	if world_environment and world_environment.environment and world_environment.environment.sky:
		var sky_mat: Material = world_environment.environment.sky.sky_material
		if sky_mat is ProceduralSkyMaterial:
			sky_energy_slider.value = sky_mat.sky_energy_multiplier
			sky_top_color_picker.color = sky_mat.sky_top_color
			sky_horizon_color_picker.color = sky_mat.sky_horizon_color
			
	if ground_plane:
		toggle_ground_btn.button_pressed = ground_plane.visible
		
	env_panel.custom_minimum_size.y = expanded_size

func _on_light_rot_x_changed(value: float) -> void:
	if light_node:
		light_node.rotation.x = deg_to_rad(value)

func _on_light_rot_changed(value: float) -> void:
	if light_node:
		light_node.rotation.y = deg_to_rad(value)

func _on_light_energy_changed(value: float) -> void:
	if light_node:
		light_node.light_energy = value

func _on_light_color_changed(color: Color) -> void:
	if light_node:
		light_node.light_color = color

func _on_sky_energy_changed(value: float) -> void:
	if world_environment and world_environment.environment and world_environment.environment.sky:
		var sky_mat: Material = world_environment.environment.sky.sky_material
		if sky_mat is ProceduralSkyMaterial:
			sky_mat.sky_energy_multiplier = value

func _on_sky_top_color_changed(color: Color) -> void:
	if world_environment and world_environment.environment and world_environment.environment.sky:
		var sky_mat: Material = world_environment.environment.sky.sky_material
		if sky_mat is ProceduralSkyMaterial:
			sky_mat.sky_top_color = color

func _on_sky_horizon_color_changed(color: Color) -> void:
	if world_environment and world_environment.environment and world_environment.environment.sky:
		var sky_mat: Material = world_environment.environment.sky.sky_material
		if sky_mat is ProceduralSkyMaterial:
			sky_mat.sky_horizon_color = color

func _on_ground_toggled(pressed: bool) -> void:
	if ground_plane:
		ground_plane.visible = pressed

func _on_toggle_env_pressed() -> void:
	is_expanded = !is_expanded
	toggle_env_btn.text = "Hide Environment" if is_expanded else "Show Environment"
	
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_height: float = expanded_size if is_expanded else 0.0
	tween.tween_property(env_panel, "custom_minimum_size:y", target_height, 0.3)
