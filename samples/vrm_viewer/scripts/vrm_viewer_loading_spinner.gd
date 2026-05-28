extends Control

@export var rotation_speed: float = 4.0
@export var line_width: float = 4.0
@export var spinner_color: Color = Color(0.0, 0.75, 1.0) # Neon Cyan

var _angle: float = 0.0

func _process(delta: float) -> void:
	if visible:
		_angle += delta * rotation_speed
		# Keep angle bounded
		if _angle > PI * 2.0:
			_angle -= PI * 2.0
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) / 2.0 - line_width

	if radius <= 0:
		return
		
	# Draw a primary rotating arc (270 degrees)
	draw_arc(center, radius, _angle, _angle + PI * 1.5, 32, spinner_color, line_width, true)
	
	# Draw a subtle background trail ring
	var trail_color: Color = spinner_color
	trail_color.a = 0.15
	draw_arc(center, radius, 0, PI * 2.0, 32, trail_color, line_width, true)
