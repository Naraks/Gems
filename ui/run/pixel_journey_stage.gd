class_name PixelJourneyStage
extends Control

const SKY := Color("10271d")
const RUINS := Color("1d3a29")
const ROAD := Color("211f17")
const ROAD_EDGE := Color("587047")
const ROAD_MARK := Color("9a8748")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY, true)
	var horizon := floorf(size.y * 0.58)
	for index in 11:
		var width := 20.0 + float((index * 13) % 27)
		var height := 12.0 + float((index * 17) % 38)
		var x := float(index) * size.x / 10.0 - width * 0.5
		draw_rect(Rect2(x, horizon - height, width, height), RUINS, true)
		if index % 3 == 0:
			draw_rect(Rect2(x + width * 0.35, horizon - height - 9.0, width * 0.3, 9.0), RUINS, true)
	draw_rect(Rect2(0.0, horizon, size.x, size.y - horizon), ROAD, true)
	draw_rect(Rect2(0.0, horizon, size.x, 3.0), ROAD_EDGE, true)
	var line_y := floorf(lerpf(horizon, size.y, 0.62))
	var dash_width := 24.0
	for x in range(18, ceili(size.x), 52):
		draw_rect(Rect2(float(x), line_y, dash_width, 3.0), ROAD_MARK, true)
	draw_rect(Rect2(0.0, 0.0, size.x, 2.0), Color(ROAD_EDGE, 0.8), true)
	draw_rect(Rect2(0.0, size.y - 2.0, size.x, 2.0), Color(ROAD_EDGE, 0.8), true)
