class_name BoardMove
extends RefCounted

var first: Vector2i
var second: Vector2i


func _init(first_position: Vector2i, second_position: Vector2i) -> void:
	first = first_position
	second = second_position


func key() -> String:
	return "%d,%d-%d,%d" % [first.x, first.y, second.x, second.y]
