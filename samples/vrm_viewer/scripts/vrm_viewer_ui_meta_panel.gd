extends VBoxContainer

@onready var content_vbox: VBoxContainer = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var thumbnail_rect: TextureRect = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/ThumbnailRect

@onready var content_panel: PanelContainer = $PanelContainer

var is_expanded: bool = true
var expanded_size: float = 430.0

func _ready() -> void:
	content_panel.custom_minimum_size.y = expanded_size

func display_metadata(vrm_meta: Resource) -> void:
	# Clear previous dynamic fields
	for child in content_vbox.get_children():
		if child != thumbnail_rect:
			child.queue_free()
			
	var thumbnail: Texture = vrm_meta.get("thumbnail_image")
	if thumbnail:
		thumbnail_rect.texture = thumbnail
		thumbnail_rect.show()
	else:
		thumbnail_rect.hide()

	_add_section_header("General Info")
	_add_meta_field("Title", vrm_meta.get("title"))
	
	var authors = vrm_meta.get("authors") if vrm_meta.get("authors") else PackedStringArray()
	_add_meta_field("Author", authors[0] if authors.size() > 0 else "")
	_add_meta_field("Contact", vrm_meta.get("contact_information"))
	_add_meta_field("Version", vrm_meta.get("version"))
	_add_meta_field("Reference", vrm_meta.get("reference_information"))

	_add_section_header("Permissions")
	_add_meta_field("Allowed User", vrm_meta.get("allowed_user_name"))
	_add_meta_field("Violent Usage", vrm_meta.get("violent_usage"))
	_add_meta_field("Sexual Usage", vrm_meta.get("sexual_usage"))
	_add_meta_field("Commercial Usage", vrm_meta.get("commercial_usage_type"))
	_add_meta_field("Political/Religious", vrm_meta.get("political_religious_usage"))
	_add_meta_field("Antisocial/Hate", vrm_meta.get("antisocial_hate_usage"))

	_add_section_header("Redistribution & License")
	_add_meta_field("Credit Notation", vrm_meta.get("credit_notation"))
	_add_meta_field("Allow Redistribution", vrm_meta.get("allow_redistribution"))
	_add_meta_field("Modification", vrm_meta.get("modification"))
	_add_meta_field("License", vrm_meta.get("license_name"))
	_add_meta_field("License URL", vrm_meta.get("license_url"))
	_add_meta_field("Third Party Licenses", vrm_meta.get("third_party_licenses"))
	_add_meta_field("Other License URL", vrm_meta.get("other_license_url"))
	_add_meta_field("Other Permission URL", vrm_meta.get("other_permission_url"))

	_add_section_header("Exporter Info")
	_add_meta_field("Exporter Version", vrm_meta.get("exporter_version"))
	_add_meta_field("Spec Version", vrm_meta.get("spec_version"))

func _add_section_header(title: String) -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 15)
	content_vbox.add_child(sep)
	
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	lbl.add_theme_font_size_override("font_size", 14)
	content_vbox.add_child(lbl)

func _add_meta_field(key: String, value: Variant) -> void:
	if value == null:
		return
	var str_val = str(value).strip_edges()
	if str_val.is_empty():
		return
		
	var lbl = Label.new()
	lbl.text = key + ": " + str_val
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	lbl.add_theme_font_size_override("font_size", 13)
	content_vbox.add_child(lbl)


