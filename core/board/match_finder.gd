class_name MatchFinder
extends RefCounted

const MatchGroupScript = preload("res://core/board/match_group.gd")
const MatchShapeScript = preload("res://core/board/match_shape.gd")
const TileTypeScript = preload("res://core/board/tile_type.gd")


func find_matches(board: RefCounted, minimum_size: int = 3) -> Array:
	assert(board != null, "MatchFinder requires a board")
	assert(minimum_size >= 3, "Minimum match size must be at least three")
	var runs := _find_runs(board, minimum_size)
	var matches: Array = []
	var visited := PackedByteArray()
	visited.resize(runs.size())
	for run_index in runs.size():
		if visited[run_index] == 1:
			continue
		var connected_indices: Array[int] = [run_index]
		visited[run_index] = 1
		var cursor := 0
		while cursor < connected_indices.size():
			var current_index := connected_indices[cursor]
			for candidate_index in runs.size():
				if visited[candidate_index] == 1:
					continue
				if _runs_intersect(runs[current_index], runs[candidate_index]):
					visited[candidate_index] = 1
					connected_indices.append(candidate_index)
			cursor += 1
		matches.append(_build_group(runs, connected_indices))
	return matches


func _find_runs(board: RefCounted, minimum_size: int) -> Array:
	var runs: Array = []
	for y in board.size.y:
		var x := 0
		while x < board.size.x:
			var tile: int = board.get_cell(Vector2i(x, y))
			var end := x + 1
			while end < board.size.x and board.get_cell(Vector2i(end, y)) == tile:
				end += 1
			if TileTypeScript.can_match(tile) and end - x >= minimum_size:
				var cells: Array[Vector2i] = []
				for run_x in range(x, end):
					cells.append(Vector2i(run_x, y))
				runs.append({"tile": tile, "cells": cells, "horizontal": true, "length": end - x})
			x = end
	for x in board.size.x:
		var y := 0
		while y < board.size.y:
			var tile: int = board.get_cell(Vector2i(x, y))
			var end := y + 1
			while end < board.size.y and board.get_cell(Vector2i(x, end)) == tile:
				end += 1
			if TileTypeScript.can_match(tile) and end - y >= minimum_size:
				var cells: Array[Vector2i] = []
				for run_y in range(y, end):
					cells.append(Vector2i(x, run_y))
				runs.append({"tile": tile, "cells": cells, "horizontal": false, "length": end - y})
			y = end
	return runs


func _runs_intersect(first: Dictionary, second: Dictionary) -> bool:
	if first.tile != second.tile:
		return false
	for cell in first.cells:
		if cell in second.cells:
			return true
	return false


func _build_group(runs: Array, indices: Array[int]) -> RefCounted:
	var unique_cells := {}
	var has_horizontal := false
	var has_vertical := false
	var longest_line := 0
	for index in indices:
		var run: Dictionary = runs[index]
		has_horizontal = has_horizontal or run.horizontal
		has_vertical = has_vertical or not run.horizontal
		longest_line = maxi(longest_line, run.length)
		for cell in run.cells:
			unique_cells[cell] = true
	var cells: Array[Vector2i] = []
	for cell in unique_cells:
		cells.append(cell)
	cells.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		return first.y < second.y or (first.y == second.y and first.x < second.x)
	)
	var shape := MatchShapeScript.Value.LINE_3
	if longest_line >= 5:
		shape = MatchShapeScript.Value.LINE_5_PLUS
	elif has_horizontal and has_vertical:
		shape = MatchShapeScript.Value.T_OR_L
	elif longest_line == 4:
		shape = MatchShapeScript.Value.LINE_4
	return MatchGroupScript.new(runs[indices[0]].tile, cells, shape, longest_line)
