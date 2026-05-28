extends Control

@export var hide_at_begin : bool = false

signal quit_pressed

func _ready() -> void:
	visible = !hide_at_begin

func _on_quit_pressed() -> void:
	quit_pressed.emit()
	visible = false
