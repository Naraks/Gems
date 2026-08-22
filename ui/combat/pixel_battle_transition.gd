class_name PixelBattleTransition
extends Control

const COLUMNS := 16
const ROWS := 9
const DARK := Color("0b1712")
const ACCENT := Color("8ebd72")

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if progress <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var cell := Vector2(ceilf(size.x / COLUMNS), ceilf(size.y / ROWS))
	for row in ROWS:
		for column in COLUMNS:
			var from_edge := minf(column, COLUMNS - 1 - column) / (COLUMNS * 0.5)
			var stagger := fmod(float(row * 7 + column * 3), 11.0) / 55.0
			var threshold := from_edge * 0.42 + stagger
			if progress < threshold:
				continue
			var rect := Rect2(Vector2(column, row) * cell, cell + Vector2.ONE)
			draw_rect(rect, DARK, true)
			if absf(progress - threshold) < 0.10:
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), Color(ACCENT, 0.72), true)
