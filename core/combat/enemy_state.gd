class_name EnemyState
extends RefCounted

var max_health: int
var health: int


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
