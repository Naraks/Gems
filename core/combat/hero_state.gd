class_name HeroState
extends RefCounted

var max_health: int
var health: int
var coins := 0
var experience := 0
var level := 1
var sword_power: float
var magic_power: float
var healing_power: float
var coin_multiplier: float
var cascade_bonus := 0.0
var last_chance_available := false
var weakness_multiplier := 1.5


func _init(
	maximum_health: int,
	current_health: int = -1,
	starting_sword_power: float = 1.0,
	starting_magic_power: float = 1.0,
	starting_healing_power: float = 1.0,
	starting_coin_multiplier: float = 1.0,
) -> void:
	assert(maximum_health > 0, "Hero maximum health must be positive")
	assert(starting_sword_power >= 0.0 and starting_magic_power >= 0.0, "Damage power cannot be negative")
	assert(starting_healing_power >= 0.0 and starting_coin_multiplier >= 0.0, "Effect power cannot be negative")
	max_health = maximum_health
	health = maximum_health if current_health < 0 else clampi(current_health, 0, max_health)
	sword_power = starting_sword_power
	magic_power = starting_magic_power
	healing_power = starting_healing_power
	coin_multiplier = starting_coin_multiplier


func take_damage(amount: int) -> int:
	assert(amount >= 0, "Damage cannot be negative")
	var previous := health
	var resulting_health := health - amount
	if resulting_health <= 0 and health > 0 and last_chance_available:
		health = 1
		last_chance_available = false
	else:
		health = maxi(0, resulting_health)
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


func add_experience(amount: int) -> void:
	assert(amount >= 0, "Experience cannot be negative")
	experience += amount


func level_up() -> bool:
	var required := experience_for_next_level()
	if experience < required:
		return false
	experience -= required
	level += 1
	return true
