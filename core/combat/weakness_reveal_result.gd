class_name WeaknessRevealResult
extends RefCounted

const AttackTypeScript = preload("res://core/combat/attack_type.gd")

var revealed := false
var hit_weakness := false
var inferred := false
var weakness_type := AttackTypeScript.Kind.NONE
