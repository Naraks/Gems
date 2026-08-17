class_name EnemyState
extends RefCounted

const AttackTypeScript = preload("res://core/combat/attack_type.gd")
const WeaknessRevealResultScript = preload("res://core/combat/weakness_reveal_result.gd")

var max_health: int
var health: int
var physical_damage_multiplier := 1.0
var magic_damage_multiplier := 1.0
var weakness_type := AttackTypeScript.Kind.NONE
var resistance_type := AttackTypeScript.Kind.NONE
var weakness_revealed := false
var current_intent: RefCounted
var experience_reward := 40


func _init(maximum_health: int, current_health: int = -1) -> void:
	assert(maximum_health > 0, "Enemy maximum health must be positive")
	max_health = maximum_health
	health = maximum_health if current_health < 0 else clampi(current_health, 0, max_health)


func take_damage(amount: int) -> int:
	assert(amount >= 0, "Damage cannot be negative")
	var previous := health
	health = maxi(0, health - amount)
	return previous - health


func heal(amount: int) -> int:
	assert(amount >= 0, "Healing cannot be negative")
	var previous := health
	health = mini(max_health, health + amount)
	return health - previous


func is_defeated() -> bool:
	return health <= 0


func configure_affinities(
	new_weakness: int,
	new_resistance: int = AttackTypeScript.Kind.NONE,
	weakness_multiplier := 1.5,
	resistance_multiplier := 0.65,
) -> void:
	assert(new_weakness != new_resistance or new_weakness == AttackTypeScript.Kind.NONE, "Weakness and resistance must differ")
	weakness_type = new_weakness
	resistance_type = new_resistance
	weakness_revealed = false
	physical_damage_multiplier = _multiplier_for(AttackTypeScript.Kind.PHYSICAL, weakness_multiplier, resistance_multiplier)
	magic_damage_multiplier = _multiplier_for(AttackTypeScript.Kind.MAGIC, weakness_multiplier, resistance_multiplier)


func reveal_weakness_from_attack(attack_type: int) -> RefCounted:
	var result = WeaknessRevealResultScript.new()
	result.weakness_type = weakness_type
	if weakness_revealed or weakness_type == AttackTypeScript.Kind.NONE or attack_type == AttackTypeScript.Kind.NONE:
		return result
	weakness_revealed = true
	result.revealed = true
	result.hit_weakness = attack_type == weakness_type
	result.inferred = not result.hit_weakness
	return result


func weakness_display() -> String:
	return AttackTypeScript.display_name(weakness_type) if weakness_revealed else "?"


func _multiplier_for(type: int, weakness_multiplier: float, resistance_multiplier: float) -> float:
	if type == weakness_type:
		return weakness_multiplier
	if type == resistance_type:
		return resistance_multiplier
	return 1.0
