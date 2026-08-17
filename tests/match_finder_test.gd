extends SceneTree

const BoardModelScript = preload("res://core/board/board_model.gd")
const MatchFinderScript = preload("res://core/board/match_finder.gd")
const MatchShapeScript = preload("res://core/board/match_shape.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")

var _finder = MatchFinderScript.new()


func _init() -> void:
	var failed := false
	failed = _check_shape([Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], MatchShapeScript.Value.LINE_3, 3, "horizontal 3") or failed
	failed = _check_shape([Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)], MatchShapeScript.Value.LINE_4, 4, "vertical 4") or failed
	failed = _check_shape([Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)], MatchShapeScript.Value.LINE_5_PLUS, 5, "horizontal 5+") or failed

	var t_cells: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]
	failed = _check_shape(t_cells, MatchShapeScript.Value.T_OR_L, 5, "T intersection") or failed
	var l_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
	failed = _check_shape(l_cells, MatchShapeScript.Value.T_OR_L, 5, "L intersection") or failed

	var strongest_cells: Array[Vector2i] = [
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(2, 1), Vector2i(2, 3),
	]
	var strongest_matches := _finder.find_matches(_board_with(strongest_cells))
	failed = _check(strongest_matches.size() == 1, "Intersecting lines form one match") or failed
	failed = _check(strongest_matches[0].shape == MatchShapeScript.Value.LINE_5_PLUS, "Strongest intersecting form wins") or failed
	failed = _check(strongest_matches[0].cells.size() == 7, "Intersection cell is counted once") or failed
	failed = _check(is_equal_approx(strongest_matches[0].multiplier(), 2.75), "5+ multiplier comes from GDD") or failed

	var separate_cells: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	]
	failed = _check(_finder.find_matches(_board_with(separate_cells)).size() == 2, "Separate lines remain separate matches") or failed
	failed = _check(_finder.find_matches(_board_with([])).is_empty(), "Empty stones never form matches") or failed

	quit(1 if failed else 0)


func _check_shape(positions: Array[Vector2i], expected_shape: int, expected_cells: int, description: String) -> bool:
	var matches := _finder.find_matches(_board_with(positions))
	return _check(matches.size() == 1 and matches[0].shape == expected_shape and matches[0].cells.size() == expected_cells, "Recognizes " + description)


func _board_with(sword_positions: Array[Vector2i]) -> RefCounted:
	var cells := PackedInt32Array()
	cells.resize(25)
	cells.fill(TileTypeScript.Value.EMPTY_STONE)
	var board = BoardModelScript.new(Vector2i(5, 5), cells)
	for position in sword_positions:
		board.set_cell(position, TileTypeScript.Value.SWORD)
	return board


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true
