extends SceneTree

const BoardModelScript = preload("res://core/board/board_model.gd")
const BoardResolverScript = preload("res://core/board/board_resolver.gd")
const BoardViewScript = preload("res://ui/board/board_view.gd")
const RULES_PATH := "res://data/game_rules.tres"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var board = BoardModelScript.new(Vector2i(3, 3), PackedInt32Array([
		1, 2, 1,
		2, 1, 2,
		0, 0, 0,
	]))
	var refill: Array[int] = [1, 1, 1, 0, 1, 2]
	var resolution = BoardResolverScript.new(
		load(RULES_PATH) as GameRules,
		1,
		func(_allow_empty: bool) -> int: return refill.pop_front(),
	).resolve(board)
	var view := BoardViewScript.new()
	view.size = Vector2(360, 360)
	root.add_child(view)
	view.setup(board)
	view.play_resolution(resolution)
	await process_frame
	failed = _check(view.animation_active, "Board animation starts before the resolved state is shown") or failed
	view.accelerate_animation()
	while view.animation_active:
		await process_frame
	failed = _check(not view.animation_active and view._animation_phase == &"", "All cascade animation phases finish cleanly") or failed
	failed = _check(view._animation_speed == view.FAST_SPEED, "Active cascade animation can be accelerated") or failed
	failed = _check(view._fall_duration(resolution.steps[0]) >= view.MIN_FALL_SECONDS, "Fall duration is derived from travelled cell distance") or failed
	view.play_swap(Vector2i(0, 0), Vector2i(1, 0), board.cells())
	await process_frame
	failed = _check(view.animation_active and view._animation_phase == &"swap", "Swap is shown as movement instead of an instant redraw") or failed
	view.accelerate_animation()
	while view.animation_active:
		await process_frame
	view.play_invalid_swap_return(Vector2i(0, 0), Vector2i(1, 0), board.cells())
	await process_frame
	failed = _check(view.animation_active and view._animation_phase == &"invalid", "Invalid swap pauses with a rejection state before returning") or failed
	view.accelerate_animation()
	while view.animation_active:
		await process_frame
	view.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true
