extends SceneTree

const BoardCollapserScript = preload("res://core/board/board_collapser.gd")
const BoardModelScript = preload("res://core/board/board_model.gd")
const BoardResolverScript = preload("res://core/board/board_resolver.gd")
const BoardTurnControllerScript = preload("res://core/board/board_turn_controller.gd")
const CascadeStepScript = preload("res://core/board/cascade_step.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")
const RULES_PATH := "res://data/game_rules.tres"


func _init() -> void:
	var failed := false
	var collapsed = BoardModelScript.new(Vector2i(2, 4), PackedInt32Array([
		0, -1,
		-1, 2,
		1, -1,
		-1, 0,
	]))
	var spawned := BoardCollapserScript.new().collapse_and_refill(collapsed, func() -> int: return TileTypeScript.Value.COIN)
	failed = _check(spawned == 4, "Refill creates one tile per empty cell") or failed
	failed = _check(collapsed.cells() == PackedInt32Array([3, 3, 3, 3, 0, 2, 1, 0]), "Tiles fall down in their original order") or failed

	var rules := load(RULES_PATH) as GameRules
	var refill: Array[int] = [1, 1, 1, 0, 1, 2]
	var board = BoardModelScript.new(Vector2i(3, 3), PackedInt32Array([
		1, 2, 1,
		2, 1, 2,
		0, 0, 0,
	]))
	var resolver = BoardResolverScript.new(rules, 1, func(_allow_empty: bool) -> int: return refill.pop_front())
	var result = resolver.resolve(board)
	failed = _check(result.stable, "Cascades resolve to a stable board") or failed
	failed = _check(result.steps.size() == 2, "New matches trigger another cascade") or failed
	failed = _check(result.total_removed == 6, "Both cascade matches are removed") or failed
	failed = _check(not board.has_any_match(), "Stable board has no remaining matches") or failed
	failed = _check(result.steps[0].multiplier == 1.0 and result.steps[1].multiplier == 1.25, "Cascade multipliers start at x1.00 and x1.25") or failed
	failed = _check(CascadeStepScript.multiplier_for(3) == 1.5, "Third cascade multiplier is x1.50") or failed
	failed = _check(CascadeStepScript.multiplier_for(4) == 1.75, "Fourth cascade multiplier is x1.75") or failed
	failed = _check(CascadeStepScript.multiplier_for(5) == 2.0, "Fifth cascade multiplier is x2.00") or failed
	failed = _check(CascadeStepScript.multiplier_for(20) == 2.0, "Cascade multiplier is capped at x2.00") or failed

	var turn_board = BoardModelScript.new(Vector2i(3, 3), PackedInt32Array([
		0, 1, 0,
		2, 0, 2,
		1, 2, 1,
	]))
	var turns = BoardTurnControllerScript.new(turn_board)
	turns.begin_swap(Vector2i(1, 0), Vector2i(1, 1))
	failed = _check(turns.finish_swap(), "Fixture commits a matching exchange") or failed
	var turn_refill: Array[int] = [1, 2, 3]
	var turn_result = BoardResolverScript.new(rules, 2, func(_allow_empty: bool) -> int: return turn_refill.pop_front()).resolve(turn_board)
	failed = _check(turn_result.steps.size() >= 1, "Committed exchange resolves its match") or failed
	failed = _check(turns.move_count == 1, "All cascades still count as one move") or failed

	var blocker_board = BoardModelScript.new(Vector2i(6, 3), PackedInt32Array([
		1, 2, 1, 2, 1, 2,
		4, 0, 0, 0, 0, 4,
		2, 1, 2, 1, 2, 1,
	]))
	var blocker_result = BoardResolverScript.new(
		rules,
		3,
		func(_allow_empty: bool) -> int: return TileTypeScript.Value.EMPTY_STONE,
	).resolve(blocker_board)
	failed = _check(blocker_result.steps.size() == 1, "Enhanced match resolves in one stable step") or failed
	failed = _check(blocker_result.total_cleared_empty_stones == 2, "Resolver clears blockers selected by line 4") or failed
	failed = _check(blocker_result.total_removed == 6, "Matched tiles and adjacent blockers are removed together") or failed

	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true
