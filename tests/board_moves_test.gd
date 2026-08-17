extends SceneTree

const BoardModelScript = preload("res://core/board/board_model.gd")
const BoardShufflerScript = preload("res://core/board/board_shuffler.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")


func _init() -> void:
	var failed := false
	var board = BoardModelScript.new(Vector2i(4, 4), PackedInt32Array([
		0, 1, 0, 2,
		2, 0, 2, 1,
		1, 2, 1, 0,
		0, 1, 2, 1,
	]))
	failed = _check(not board.has_any_match(), "Fixture starts without matches") or failed
	var moves: Array = board.find_valid_moves()
	failed = _check(not moves.is_empty(), "Valid moves are found") or failed
	failed = _check(_keys(moves) == _brute_force_keys(board), "Finder returns every unique valid swap") or failed
	for move in moves:
		board.swap(move.first, move.second)
		failed = _check(board.has_any_match(), "Reported move %s creates a match" % move.key(), false) or failed
		board.swap(move.first, move.second)

	var stuck = BoardModelScript.new(Vector2i(3, 3), PackedInt32Array([
		0, 1, 2,
		1, 2, 0,
		2, 0, 1,
	]))
	failed = _check(not stuck.has_any_match(), "Stuck fixture has no matches") or failed
	failed = _check(not stuck.has_valid_move(), "Stuck fixture has no valid moves") or failed
	var original_counts := _tile_counts(stuck)
	var shuffled := BoardShufflerScript.new(42).reshuffle_if_stuck(stuck)
	failed = _check(shuffled, "Stuck board is reshuffled") or failed
	failed = _check(_tile_counts(stuck) == original_counts, "Reshuffle preserves all tiles") or failed
	failed = _check(not stuck.has_any_match(), "Reshuffled board has no ready matches") or failed
	failed = _check(stuck.has_valid_move(), "Reshuffled board has a valid move") or failed
	var unchanged := stuck.cells()
	failed = _check(not BoardShufflerScript.new(7).reshuffle_if_stuck(stuck), "Playable board is not reshuffled") or failed
	failed = _check(stuck.cells() == unchanged, "Playable board remains unchanged") or failed

	quit(1 if failed else 0)


func _brute_force_keys(board: RefCounted) -> PackedStringArray:
	var keys := PackedStringArray()
	for y in board.size.y:
		for x in board.size.x:
			var first := Vector2i(x, y)
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var second: Vector2i = first + direction
				if not board.contains(second) or board.get_cell(first) == board.get_cell(second):
					continue
				board.swap(first, second)
				if board.has_any_match():
					keys.append("%d,%d-%d,%d" % [first.x, first.y, second.x, second.y])
				board.swap(first, second)
	keys.sort()
	return keys


func _keys(moves: Array) -> PackedStringArray:
	var keys := PackedStringArray()
	for move in moves:
		keys.append(move.key())
	keys.sort()
	return keys


func _tile_counts(board: RefCounted) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(TileTypeScript.COUNT)
	for tile in board.cells():
		counts[tile] += 1
	return counts


func _check(condition: bool, description: String, verbose: bool = true) -> bool:
	if condition:
		if verbose:
			print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true
