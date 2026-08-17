class_name BoardShuffler
extends RefCounted

const BoardModelScript = preload("res://core/board/board_model.gd")
const MAX_SHUFFLE_ATTEMPTS := 1024

var _random := RandomNumberGenerator.new()


func _init(seed: int = 0) -> void:
	if seed == 0:
		_random.randomize()
	else:
		_random.seed = seed


## Rearranges the existing tiles in place. No turn or combat state is touched.
func reshuffle(board: RefCounted, minimum_match_size: int = 3) -> bool:
	assert(board != null, "BoardShuffler requires a board")
	var original_cells: PackedInt32Array = board.cells()
	for _attempt in MAX_SHUFFLE_ATTEMPTS:
		var shuffled_cells := original_cells.duplicate()
		_shuffle(shuffled_cells)
		var candidate = BoardModelScript.new(board.size, shuffled_cells)
		if candidate.has_any_match(minimum_match_size):
			continue
		if not candidate.has_valid_move(minimum_match_size):
			continue
		board.replace_cells(shuffled_cells)
		return true
	return false


func reshuffle_if_stuck(board: RefCounted, minimum_match_size: int = 3) -> bool:
	if board.has_valid_move(minimum_match_size):
		return false
	return reshuffle(board, minimum_match_size)


func _shuffle(values: PackedInt32Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := _random.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[other]
		values[other] = temporary
