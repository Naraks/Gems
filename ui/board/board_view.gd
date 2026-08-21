class_name BoardView
extends Control

signal swap_requested(first: Vector2i, second: Vector2i)

const BoardInputControllerScript = preload("res://core/board/board_input_controller.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")
const TILE_COLORS := [
	Color("#e85b43"),
	Color("#5878e8"),
	Color("#e45191"),
	Color("#e2ad36"),
	Color("#56616c"),
]
const TILE_LABELS := ["⚔", "✦", "♥", "●", "◆"]
const BOARD_COLOR := Color("#101b19")
const BOARD_EDGE := Color("#8ebd72")

var _board: RefCounted
var _input_controller: RefCounted


func setup(board: RefCounted) -> void:
	assert(board != null, "BoardView requires a board")
	_board = board
	_input_controller = BoardInputControllerScript.new(board.size)
	_input_controller.swap_requested.connect(_on_swap_requested)
	_input_controller.selection_changed.connect(_on_selection_changed)
	queue_redraw()


func set_input_enabled(enabled: bool) -> void:
	if _input_controller != null:
		_input_controller.set_input_enabled(enabled)
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	queue_redraw()


func cell_at(local_position: Vector2) -> Vector2i:
	if _board == null:
		return BoardInputControllerScript.NO_POSITION
	var board_rect := _board_rect()
	if not board_rect.has_point(local_position):
		return BoardInputControllerScript.NO_POSITION
	var cell_size := board_rect.size / Vector2(_board.size)
	var relative := local_position - board_rect.position
	return Vector2i(floori(relative.x / cell_size.x), floori(relative.y / cell_size.y))


func _gui_input(event: InputEvent) -> void:
	if _input_controller == null or not _input_controller.input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(event.position, event.pressed)
		accept_event()
	elif event is InputEventScreenTouch:
		_handle_pointer(event.position, event.pressed)
		accept_event()


func _draw() -> void:
	if _board == null:
		return
	var board_rect := _board_rect()
	var cell_size := board_rect.size / Vector2(_board.size)
	var font := get_theme_default_font()
	var font_size := maxi(16, floori(minf(cell_size.x, cell_size.y) * 0.43))
	var frame := board_rect.grow(12.0)
	draw_style_box(_board_style(), frame)
	for y in _board.size.y:
		for x in _board.size.x:
			var position := Vector2i(x, y)
			var tile: int = _board.get_cell(position)
			var gap := maxf(2.0, minf(cell_size.x, cell_size.y) * 0.045)
			var rect := Rect2(board_rect.position + Vector2(position) * cell_size, cell_size).grow(-gap)
			draw_rect(Rect2(rect.position + Vector2(0.0, gap * 0.7), rect.size), Color(0.01, 0.02, 0.02, 0.72), true)
			draw_rect(rect, TILE_COLORS[tile].darkened(0.12), true)
			draw_rect(rect.grow(-2.0), TILE_COLORS[tile], true)
			draw_line(rect.position + Vector2(3, 3), Vector2(rect.end.x - 3, rect.position.y + 3), TILE_COLORS[tile].lightened(0.38), 2.0)
			draw_line(Vector2(rect.position.x + 3, rect.end.y - 3), rect.end - Vector2(3, 3), TILE_COLORS[tile].darkened(0.38), 2.0)
			var label: String = TILE_LABELS[tile]
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var baseline := rect.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
			draw_string(font, baseline + Vector2(1, 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.05, 0.05, 0.05, 0.65))
			draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#fff8e8"))
			if _input_controller.selected_position == position:
				draw_rect(rect.grow(2.0), Color("#fff1a8"), false, 4.0)


func _handle_pointer(local_position: Vector2, pressed: bool) -> void:
	var cell := cell_at(local_position)
	if pressed:
		_input_controller.begin_pointer(cell)
	else:
		_input_controller.end_pointer(cell)


func _board_rect() -> Rect2:
	var padding := clampf(minf(size.x, size.y) * 0.035, 10.0, 24.0)
	var side := minf(size.x, size.y) - padding * 2.0
	return Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)


func _board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BOARD_COLOR
	style.border_color = Color(BOARD_EDGE, 0.75)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 10
	return style


func _on_swap_requested(first: Vector2i, second: Vector2i) -> void:
	swap_requested.emit(first, second)


func _on_selection_changed(_position: Vector2i) -> void:
	queue_redraw()
