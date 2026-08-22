class_name PixelAudioButton
extends Button

enum Kind { MUSIC, SFX }

@export var kind := Kind.MUSIC
var active := true


func _ready() -> void:
	text = ""
	queue_redraw()


func set_active(value: bool) -> void:
	active = value
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var background := Color("#10201b") if active else Color("#171b19")
	var border := Color("#9dcc75") if active else Color("#7d8781")
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.55), true)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), background, true)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), border, false, 2.0)
	var color := Color("#efffcf") if active else Color("#b6beb9")
	if kind == Kind.MUSIC:
		_draw_music(center, color)
	else:
		_draw_speaker(center, color)
	if not active:
		draw_line(center + Vector2(-15, -14), center + Vector2(15, 14), Color("#7c211d"), 6.0)
		draw_line(center + Vector2(-15, -14), center + Vector2(15, 14), Color("#ff6b5f"), 3.0)


func _draw_music(center: Vector2, color: Color) -> void:
	var origin := center + Vector2(-4, -14)
	draw_rect(Rect2(origin, Vector2(5, 24)), color)
	draw_rect(Rect2(origin + Vector2(5, 0), Vector2(13, 5)), color)
	draw_rect(Rect2(origin + Vector2(13, 3), Vector2(5, 11)), color)
	draw_rect(Rect2(origin + Vector2(-9, 9), Vector2(12, 9)), color)
	draw_rect(Rect2(origin + Vector2(6, 12), Vector2(12, 9)), color)


func _draw_speaker(center: Vector2, color: Color) -> void:
	var left := center + Vector2(-15, -8)
	draw_rect(Rect2(left, Vector2(7, 16)), color)
	draw_colored_polygon(PackedVector2Array([
		left + Vector2(7, 2),
		left + Vector2(16, -5),
		left + Vector2(16, 21),
		left + Vector2(7, 14),
	]), color)
	if active:
		draw_arc(center + Vector2(3, 0), 11.0, -0.75, 0.75, 8, color, 3.0)
		draw_arc(center + Vector2(3, 0), 17.0, -0.65, 0.65, 8, Color(color, 0.78), 3.0)
