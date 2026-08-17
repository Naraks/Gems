class_name BoardTurnController
extends RefCounted

signal turn_committed(move_count: int)
signal invalid_swap_reverted(first: Vector2i, second: Vector2i)

var board: RefCounted
var minimum_match_size: int
var move_count := 0
var is_resolving := false

var _active_first := Vector2i(-1, -1)
var _active_second := Vector2i(-1, -1)


func _init(board_model: RefCounted, match_size: int = 3) -> void:
	assert(board_model != null, "BoardTurnController requires a board")
	assert(match_size >= 3, "Minimum match size must be at least three")
	board = board_model
	minimum_match_size = match_size


## Applies a temporary swap so the view can present it before validation.
func begin_swap(first: Vector2i, second: Vector2i) -> bool:
	if is_resolving or not board.contains(first) or not board.contains(second):
		return false
	var difference := (first - second).abs()
	if difference.x + difference.y != 1:
		return false
	is_resolving = true
	_active_first = first
	_active_second = second
	board.swap(first, second)
	return true


## Commits a matching swap or restores the exact state from before begin_swap().
func finish_swap() -> bool:
	if not is_resolving:
		return false
	var first := _active_first
	var second := _active_second
	var is_valid: bool = (
		board.has_match_at(first, minimum_match_size)
		or board.has_match_at(second, minimum_match_size)
	)
	if is_valid:
		move_count += 1
		_clear_active_swap()
		turn_committed.emit(move_count)
		return true
	board.swap(first, second)
	_clear_active_swap()
	invalid_swap_reverted.emit(first, second)
	return false


func _clear_active_swap() -> void:
	is_resolving = false
	_active_first = Vector2i(-1, -1)
	_active_second = Vector2i(-1, -1)
