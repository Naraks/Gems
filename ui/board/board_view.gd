class_name BoardView
extends Control

signal swap_requested(first: Vector2i, second: Vector2i)

const BoardInputControllerScript = preload("res://core/board/board_input_controller.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")
const TILE_COLORS := [
	Color("#d95b43"),
	Color("#5b77d9"),
	Color("#d9578b"),
	Color("#d9ad43"),
	Color("#59636e"),
]
const TILE_LABELS := ["S", "M", "H", "C", "X"]

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
	var font_size := maxi(12, floori(minf(cell_size.x, cell_size.y) * 0.32))
	for y in _board.size.y:
		for x in _board.size.x:
			var position := Vector2i(x, y)
			var tile: int = _board.get_cell(position)
			var rect := Rect2(board_rect.position + Vector2(position) * cell_size, cell_size).grow(-2.0)
			draw_rect(rect, TILE_COLORS[tile], true)
			draw_rect(rect, Color("#f2f5f7"), false, 1.0)
			var label: String = TILE_LABELS[tile]
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var baseline := rect.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
			draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			if _input_controller.selected_position == position:
				draw_rect(rect.grow(-1.0), Color.WHITE, false, 3.0)


func _handle_pointer(local_position: Vector2, pressed: bool) -> void:
	var cell := cell_at(local_position)
	if pressed:
		_input_controller.begin_pointer(cell)
	else:
		_input_controller.end_pointer(cell)


func _board_rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)


func _on_swap_requested(first: Vector2i, second: Vector2i) -> void:
	swap_requested.emit(first, second)


func _on_selection_changed(_position: Vector2i) -> void:
	queue_redraw()
