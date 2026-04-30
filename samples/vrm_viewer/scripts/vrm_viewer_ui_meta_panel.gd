extends VBoxContainer

@onready var title_label: Label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var author_label: Label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/AuthorLabel
@onready var version_label: Label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/VersionLabel
@onready var license_label: Label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/LicenseLabel
@onready var reference_label: Label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/ReferenceLabel
@onready var thumbnail_rect: TextureRect = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/ThumbnailRect

@onready var toggle_btn: Button = $ToggleMetaButton
@onready var content_panel: PanelContainer = $PanelContainer

var is_expanded: bool = true
var expanded_size: float = 430.0

func _ready() -> void:
	toggle_btn.pressed.connect(_on_toggle_pressed)
	content_panel.custom_minimum_size.y = expanded_size

func display_metadata(vrm_meta: Resource) -> void:
	if not vrm_meta:
		return
		
	var title: String = vrm_meta.get("title") if vrm_meta.get("title") else ""
	title_label.text = "Title: " + (title if not title.is_empty() else "Unknown")
	
	var authors = vrm_meta.get("authors") if vrm_meta.get("authors") else PackedStringArray()
	author_label.text = "Author: " + (authors[0] if authors.size() > 0 else "Unknown")
	
	var version: String = vrm_meta.get("version") if vrm_meta.get("version") else ""
	version_label.text = "Version: " + (version if not version.is_empty() else "Unknown")
	
	var license: String = vrm_meta.get("license_name") if vrm_meta.get("license_name") else ""
	license_label.text = "License: " + (license if not license.is_empty() else "Unknown")

	var reference: String = vrm_meta.get("reference_information") if vrm_meta.get("reference_information") else ""
	reference_label.text = "Reference: " + (reference if not reference.is_empty() else "Unknown")
	
	var thumbnail: Texture = vrm_meta.get("thumbnail_image")
	if thumbnail:
		thumbnail_rect.texture = thumbnail
		thumbnail_rect.show()
	else:
		thumbnail_rect.hide()

func _on_toggle_pressed() -> void:
	is_expanded = not is_expanded
	toggle_btn.text = "Hide Info" if is_expanded else "Show Info"
	
	var target_height: float = expanded_size if is_expanded else 0.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(content_panel, "custom_minimum_size:y", target_height, 0.3)
