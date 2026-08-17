class_name MatchGroup
extends RefCounted

const MatchShapeScript = preload("res://core/board/match_shape.gd")

var tile: int
var cells: Array[Vector2i]
var shape: int
var longest_line: int


func _init(tile_type: int, matched_cells: Array[Vector2i], match_shape: int, maximum_line: int) -> void:
	tile = tile_type
	cells = matched_cells.duplicate()
	shape = match_shape
	longest_line = maximum_line


func multiplier() -> float:
	return MatchShapeScript.multiplier(shape)
