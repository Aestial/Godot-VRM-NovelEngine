extends CharacterBody3D

@export_category("Character")
@export var character_name: String = "Char_Name"

@export_category("Animation")
@onready var animation_tree: AnimationTree = $AnimationTree

@export var initial_anim: String = "Idle":
	set(v):
		initial_anim = v
		if (animation_tree):
			animation_tree.initial_anim = v
@export var relaxed_base: float = 0.5:
	set(v):
		relaxed_base = v
		if (animation_tree):
			animation_tree.relaxed_base = v
@export var twerk_blend_amount: float = 0.5:
	set(v):
		twerk_blend_amount = v
		if (animation_tree):
			animation_tree.twerk_blend_amount = v
