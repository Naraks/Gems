class_name BoardCollapser
extends RefCounted

const EMPTY_CELL := -1


func collapse_and_refill(board: RefCounted, tile_provider: Callable) -> int:
	return int(collapse_and_refill_with_plan(board, tile_provider).spawned_tiles)


func collapse_and_refill_with_plan(board: RefCounted, tile_provider: Callable) -> Dictionary:
	assert(board != null, "BoardCollapser requires a board")
	assert(tile_provider.is_valid(), "BoardCollapser requires a tile provider")
	var spawned := 0
	var movements: Array[Dictionary] = []
	var spawns: Array[Dictionary] = []
	for x in board.size.x:
		var write_y: int = board.size.y - 1
		for read_y in range(board.size.y - 1, -1, -1):
			var tile: int = board.get_cell(Vector2i(x, read_y))
			if tile == EMPTY_CELL:
				continue
			board.set_cell(Vector2i(x, write_y), tile)
			movements.append({
				"tile": tile,
				"from": Vector2i(x, read_y),
				"to": Vector2i(x, write_y),
			})
			if write_y != read_y:
				board.set_cell(Vector2i(x, read_y), EMPTY_CELL)
			write_y -= 1
		var empty_count := write_y + 1
		while write_y >= 0:
			var tile := int(tile_provider.call())
			board.set_cell(Vector2i(x, write_y), tile)
			spawns.append({
				"tile": tile,
				"from": Vector2i(x, write_y - empty_count),
				"to": Vector2i(x, write_y),
			})
			spawned += 1
			write_y -= 1
	return {
		"spawned_tiles": spawned,
		"movements": movements,
		"spawns": spawns,
	}
