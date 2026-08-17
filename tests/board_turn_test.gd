extends SceneTree

const BoardModelScript = preload("res://core/board/board_model.gd")
const BoardTurnControllerScript = preload("res://core/board/board_turn_controller.gd")


func _init() -> void:
	var failed := false
	var board = BoardModelScript.new(Vector2i(3, 3), PackedInt32Array([
		0, 1, 0,
		2, 0, 2,
		1, 2, 1,
	]))
	var controller = BoardTurnControllerScript.new(board)
	var committed_turns: Array[int] = []
	var reverted_swaps: Array = []
	controller.turn_committed.connect(func(count: int) -> void: committed_turns.append(count))
	controller.invalid_swap_reverted.connect(func(first: Vector2i, second: Vector2i) -> void: reverted_swaps.append([first, second]))

	var initial_cells := board.cells()
	failed = _check(controller.begin_swap(Vector2i(0, 1), Vector2i(1, 1)), "Adjacent invalid swap begins") or failed
	failed = _check(controller.is_resolving, "Controller is resolving during preview") or failed
	failed = _check(board.cells() != initial_cells, "Invalid swap is visible during preview") or failed
	failed = _check(not controller.finish_swap(), "Swap without a match is rejected") or failed
	failed = _check(board.cells() == initial_cells, "Invalid swap restores exact board state") or failed
	failed = _check(controller.move_count == 0, "Invalid swap does not increment move count") or failed
	failed = _check(committed_turns.is_empty(), "Invalid swap emits no committed turn for enemy response") or failed
	failed = _check(reverted_swaps.size() == 1, "Invalid swap emits rollback notification") or failed

	failed = _check(controller.begin_swap(Vector2i(1, 0), Vector2i(1, 1)), "Adjacent valid swap begins") or failed
	failed = _check(not controller.begin_swap(Vector2i(0, 0), Vector2i(0, 1)), "Input is rejected while a swap resolves") or failed
	failed = _check(controller.finish_swap(), "Swap creating a match is committed") or failed
	failed = _check(board.cells() != initial_cells, "Valid swap remains on the board") or failed
	failed = _check(controller.move_count == 1, "Valid swap increments move count once") or failed
	failed = _check(committed_turns == [1], "Only valid swap emits committed turn") or failed
	failed = _check(not controller.is_resolving, "Controller unlocks after resolution") or failed

	failed = _check(not controller.begin_swap(Vector2i(0, 0), Vector2i(2, 0)), "Non-adjacent swap cannot begin") or failed
	failed = _check(controller.move_count == 1, "Rejected request does not change move count") or failed

	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true
