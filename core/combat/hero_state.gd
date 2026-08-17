class_name HeroState
extends RefCounted

var max_health: int
var health: int
var coins := 0
var experience := 0
var level := 1


func _init(maximum_health: int, current_health: int = -1) -> void:
	assert(maximum_health > 0, "Hero maximum health must be positive")
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


func add_coins(amount: int) -> void:
	assert(amount >= 0, "Coins cannot be negative")
	coins += amount


func is_defeated() -> bool:
	return health <= 0


func experience_for_next_level() -> int:
	return 40 + 20 * (level - 1)


func can_level_up() -> bool:
	return experience >= experience_for_next_level()
