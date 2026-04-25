extends CharacterBody3D

@export_category("Character")
@export var character_name: String = "Char_Name"

@export_category("Animation")
@onready var animation_tree: AnimationTree = $AnimationTree

@export var dancing_offset: float = 0.5:
	set(v):
		dancing_offset = v
		if (animation_tree):
			animation_tree.dancing_offset = v

@export var relaxed_offset: float = 0.5:
	set(v):
		relaxed_offset = v
		if (animation_tree):
			animation_tree.relaxed_offset = v
