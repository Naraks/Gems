class_name PixelJourneyMarker
extends ColorRect

@export var border_color := Color("8ebd72")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var frame := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	draw_rect(frame, border_color, false, 3.0)
	draw_rect(Rect2(1, 1, 7, 7), border_color, true)
	draw_rect(Rect2(size.x - 8, size.y - 8, 7, 7), border_color, true)
