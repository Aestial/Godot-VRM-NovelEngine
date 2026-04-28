extends Panel

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var author_label: Label = $VBoxContainer/AuthorLabel
@onready var version_label: Label = $VBoxContainer/VersionLabel
@onready var license_label: Label = $VBoxContainer/LicenseLabel
@onready var reference_label: Label = $VBoxContainer/ReferenceLabel
@onready var thumbnail_rect: TextureRect = $VBoxContainer/ThumbnailRect

var is_expanded: bool = true
var full_height: float = 430.0

func _ready() -> void:
	clip_contents = true
	custom_minimum_size.y = full_height

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

func toggle_expansion() -> void:
	is_expanded = not is_expanded
	var target_height = full_height if is_expanded else 0.0
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "custom_minimum_size:y", target_height, 0.3)
