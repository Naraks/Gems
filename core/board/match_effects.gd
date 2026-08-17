class_name MatchEffects
extends RefCounted

var physical_damage := 0
var magic_damage := 0
var healing := 0
var coins := 0
var physical_components: Array[float] = []
var magic_components: Array[float] = []
var healing_components: Array[float] = []
var coin_components: Array[float] = []
var cleared_empty_stones: Array[Vector2i] = []


func update_rounded_totals() -> void:
	physical_damage = _rounded_sum(physical_components)
	magic_damage = _rounded_sum(magic_components)
	healing = _rounded_sum(healing_components)
	coins = _rounded_sum(coin_components)


func _rounded_sum(components: Array[float]) -> int:
	var total := 0
	for component in components:
		total += ceili(component)
	return total
