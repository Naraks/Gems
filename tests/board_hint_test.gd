extends SceneTree

const BoardModelScript = preload("res://core/board/board_model.gd")
const BoardViewScript = preload("res://ui/board/board_view.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var board = BoardModelScript.new(Vector2i(4, 4), PackedInt32Array([
		0, 1, 0, 2,
		2, 0, 2, 1,
		1, 2, 1, 0,
		0, 1, 2, 1,
	]))
	var view = BoardViewScript.new()
	view.size = Vector2(400, 400)
	view.hint_delay_seconds = 0.1
	root.add_child(view)
	view.setup(board)
	await process_frame

	view._process(0.11)
	failed = _check(view.hint_visible and view.hinted_cells.size() == 2, "Idle stable board shows a two-gem hint") or failed
	if view.hinted_cells.size() == 2:
		board.swap(view.hinted_cells[0], view.hinted_cells[1])
		failed = _check(board.has_any_match(), "Hint always points to a swap that creates a match") or failed
		board.swap(view.hinted_cells[0], view.hinted_cells[1])

	view._input_controller.tap(Vector2i(0, 0))
	failed = _check(not view.hint_visible and is_zero_approx(view._hint_elapsed), "Selecting a gem hides the hint and resets its timer") or failed
	view._process(0.05)
	failed = _check(not view.hint_visible, "Hint delay starts again after interaction") or failed

	view.animation_active = true
	view._process(1.0)
	failed = _check(not view.hint_visible and is_zero_approx(view._hint_elapsed), "Hint stays hidden while a turn is resolving") or failed
	view.animation_active = false
	view.set_input_enabled(false)
	view._process(1.0)
	failed = _check(not view.hint_visible, "Hint stays hidden while board input is blocked") or failed

	view.set_input_enabled(true)
	view.set_hint_enabled(false)
	view._process(1.0)
	failed = _check(not view.hint_visible, "Hint stays hidden during tutorial") or failed
	view.set_hint_enabled(true)
	view._process(0.11)
	failed = _check(view.hint_visible, "Hint timer resumes after blocked state ends") or failed

	view.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true
