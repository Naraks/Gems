extends SceneTree

const RULES_PATH := "res://data/game_rules.tres"
const SAMPLE_SIZE := 500
const BoardGeneratorScript = preload("res://core/board/board_generator.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")


func _init() -> void:
	var failed := false
	var rules := load(RULES_PATH) as GameRules
	failed = _check(rules != null, "GameRules resource loads") or failed
	if rules == null:
		quit(1)
		return

	var type_counts := PackedInt32Array()
	type_counts.resize(TileTypeScript.COUNT)
	for seed in range(1, SAMPLE_SIZE + 1):
		var board = BoardGeneratorScript.new(rules, seed).generate_starting_board()
		failed = _check(board != null, "Board %d generated" % seed, false) or failed
		if board == null:
			continue
		failed = _check(board.cell_count() == 49, "Board %d has 49 cells" % seed, false) or failed
		failed = _check(not board.has_any_match(), "Board %d has no initial matches" % seed, false) or failed
		failed = _check(board.has_valid_move(), "Board %d has a valid move" % seed, false) or failed
		var empty_stones := 0
		for tile in board.cells():
			failed = _check(TileTypeScript.is_valid(tile), "Board %d contains known tiles" % seed, false) or failed
			type_counts[tile] += 1
			if tile == TileTypeScript.Value.EMPTY_STONE:
				empty_stones += 1
		failed = _check(empty_stones <= rules.maximum_empty_stones, "Board %d respects blocker limit" % seed, false) or failed

	var total_tiles := SAMPLE_SIZE * 49
	failed = _check(type_counts.size() == TileTypeScript.COUNT, "Generator produces five tile types") or failed
	var counted_tiles := 0
	for count in type_counts:
		counted_tiles += count
	failed = _check(counted_tiles == total_tiles, "All generated tiles counted") or failed

	var first = BoardGeneratorScript.new(rules, 42).generate_starting_board()
	var second = BoardGeneratorScript.new(rules, 42).generate_starting_board()
	failed = _check(first.cells() == second.cells(), "Seeded generation is deterministic") or failed

	if not failed:
		print("PASS: Generated %d valid 7x7 starting boards" % SAMPLE_SIZE)
		print("Tile counts: ", type_counts)
	quit(1 if failed else 0)


func _check(condition: bool, description: String, verbose: bool = true) -> bool:
	if condition:
		if verbose:
			print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true
