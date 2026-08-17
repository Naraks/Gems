class_name BoardResolutionResult
extends RefCounted

var steps: Array = []
var stable := true
var total_removed := 0
var total_physical_damage := 0
var total_magic_damage := 0
var total_healing := 0
var total_coins := 0
var total_cleared_empty_stones := 0
var physical_components: Array[float] = []
var magic_components: Array[float] = []
var healing_components: Array[float] = []
var coin_components: Array[float] = []


func add_step(step: RefCounted) -> void:
	steps.append(step)
	total_removed += step.removed_cells.size()
	total_physical_damage += step.effects.physical_damage
	total_magic_damage += step.effects.magic_damage
	total_healing += step.effects.healing
	total_coins += step.effects.coins
	total_cleared_empty_stones += step.effects.cleared_empty_stones.size()
	physical_components.append_array(step.effects.physical_components)
	magic_components.append_array(step.effects.magic_components)
	healing_components.append_array(step.effects.healing_components)
	coin_components.append_array(step.effects.coin_components)
