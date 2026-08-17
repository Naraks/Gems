class_name CombatTurnResult
extends RefCounted

const AttackTypeScript = preload("res://core/combat/attack_type.gd")

var phase_order: PackedStringArray = []
var physical_damage_applied := 0
var magic_damage_applied := 0
var healing_applied := 0
var coins_granted := 0
var enemy_responded := false
var victory := false
var defeat := false
var level_up_pending := false
var weakness_revealed := false
var weakness_hit := false
var weakness_inferred := false
var weakness_type := AttackTypeScript.Kind.NONE
var enemy_intent: RefCounted
