class_name BoardInputController
extends RefCounted

signal swap_requested(first: Vector2i, second: Vector2i)
signal selection_changed(position: Vector2i)

const NO_POSITION := Vector2i(-1, -1)

var board_size: Vector2i
var input_enabled := true
var selected_position := NO_POSITION
var _pointer_origin := NO_POSITION


func _init(value: Vector2i) -> void:
	assert(value.x > 0 and value.y > 0, "Board size must be positive")
	board_size = value


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		_pointer_origin = NO_POSITION
		_set_selection(NO_POSITION)


func tap(position: Vector2i) -> void:
	if not input_enabled or not contains(position):
		return
	if selected_position == NO_POSITION:
		_set_selection(position)
		return
	if selected_position == position:
		_set_selection(NO_POSITION)
		return
	if are_adjacent(selected_position, position):
		var first := selected_position
		_set_selection(NO_POSITION)
		swap_requested.emit(first, position)
		return
	_set_selection(position)


func begin_pointer(position: Vector2i) -> void:
	if input_enabled and contains(position):
		_pointer_origin = position


func end_pointer(position: Vector2i) -> void:
	if not input_enabled or _pointer_origin == NO_POSITION:
		_pointer_origin = NO_POSITION
		return
	var origin := _pointer_origin
	_pointer_origin = NO_POSITION
	if origin == position:
		tap(position)
	elif contains(position) and are_adjacent(origin, position):
		_set_selection(NO_POSITION)
		swap_requested.emit(origin, position)


func contains(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < board_size.x and position.y < board_size.y


func are_adjacent(first: Vector2i, second: Vector2i) -> bool:
	var difference := (first - second).abs()
	return difference.x + difference.y == 1


func _set_selection(position: Vector2i) -> void:
	if selected_position == position:
		return
	selected_position = position
	selection_changed.emit(position)
