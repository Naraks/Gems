class_name CombatTurnResult
extends RefCounted

var phase_order: PackedStringArray = []
var physical_damage_applied := 0
var magic_damage_applied := 0
var healing_applied := 0
var coins_granted := 0
var enemy_responded := false
var victory := false
var defeat := false
var level_up_pending := false
