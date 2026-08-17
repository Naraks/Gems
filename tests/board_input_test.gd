extends SceneTree

const BoardInputControllerScript = preload("res://core/board/board_input_controller.gd")


func _init() -> void:
	var failed := false
	var controller = BoardInputControllerScript.new(Vector2i(7, 7))
	var swaps: Array = []
	controller.swap_requested.connect(func(first: Vector2i, second: Vector2i) -> void: swaps.append([first, second]))

	controller.tap(Vector2i(1, 1))
	controller.tap(Vector2i(2, 1))
	failed = _check(swaps.size() == 1, "Two adjacent taps request a swap") or failed
	failed = _check(swaps[0] == [Vector2i(1, 1), Vector2i(2, 1)], "Tap swap keeps cell order") or failed

	controller.begin_pointer(Vector2i(3, 3))
	controller.end_pointer(Vector2i(3, 4))
	failed = _check(swaps.size() == 2, "Drag to an adjacent cell requests a swap") or failed

	controller.tap(Vector2i(0, 0))
	controller.tap(Vector2i(6, 6))
	failed = _check(swaps.size() == 2, "Non-adjacent taps do not request a swap") or failed
	controller.begin_pointer(Vector2i(0, 0))
	controller.end_pointer(Vector2i(2, 0))
	failed = _check(swaps.size() == 2, "Non-adjacent drag does not request a swap") or failed

	controller.set_input_enabled(false)
	controller.tap(Vector2i(4, 4))
	controller.tap(Vector2i(4, 5))
	controller.begin_pointer(Vector2i(4, 4))
	controller.end_pointer(Vector2i(5, 4))
	failed = _check(swaps.size() == 2, "Disabled input ignores taps and drag") or failed
	failed = _check(controller.selected_position == BoardInputControllerScript.NO_POSITION, "Disabling input clears selection") or failed

	controller.set_input_enabled(true)
	controller.tap(Vector2i(6, 6))
	controller.tap(Vector2i(7, 6))
	failed = _check(swaps.size() == 2, "Positions outside the board are ignored") or failed

	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true
