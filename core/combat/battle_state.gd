class_name BattleState
extends RefCounted

var hero: RefCounted
var enemy: RefCounted
var is_over := false
var victory := false
var defeat := false
var level_up_pending := false
var enemy_actions_executed := 0


func _init(hero_state: RefCounted, enemy_state: RefCounted) -> void:
	assert(hero_state != null and enemy_state != null, "Battle requires hero and enemy")
	hero = hero_state
	enemy = enemy_state


func finish_victory() -> void:
	is_over = true
	victory = true
	defeat = false


func finish_defeat() -> void:
	is_over = true
	defeat = true
	victory = false
