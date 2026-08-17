class_name BoardResolutionResult
extends RefCounted

var steps: Array = []
var stable := true
var total_removed := 0


func add_step(step: RefCounted) -> void:
	steps.append(step)
	total_removed += step.removed_cells.size()
