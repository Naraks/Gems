class_name EconomyRules
extends Resource

## Data-driven enemy scaling and shop economy from GDD v1.0.

@export_category("Enemy scaling")
@export_range(1, 10000, 1) var enemy_base_health := 45
@export_range(0, 1000, 1) var enemy_base_damage := 8
@export_range(0, 1000, 1) var enemy_base_experience := 18
@export_range(0, 1000, 1) var enemy_base_coins := 5
@export_range(1, 100, 1) var battles_per_cycle := 30
@export_range(0.0, 1.0, 0.001) var health_growth_per_battle := 0.075
@export_range(0.0, 1.0, 0.001) var damage_growth_per_battle := 0.055
@export_range(0.0, 1.0, 0.001) var experience_growth_per_battle := 0.045
@export_range(0.0, 1.0, 0.001) var health_growth_per_cycle := 0.025
@export_range(0.0, 1.0, 0.001) var damage_growth_per_cycle := 0.015
@export_range(1, 100, 1) var coin_battle_interval := 3
@export_range(1.0, 10.0, 0.05) var boss_health_multiplier := 2.4
@export_range(1.0, 10.0, 0.05) var boss_damage_multiplier := 1.15

@export_category("Shop economy")
@export_range(0.0, 1.0, 0.01) var price_growth_per_boss := 0.08
@export_range(1, 100, 1) var price_rounding_step := 5
@export_range(0, 1000, 1) var small_heal_price := 20
@export_range(0, 1000, 1) var full_heal_price := 55
@export_range(0, 1000, 1) var fortify_price := 60
@export_range(0, 1000, 1) var sword_power_price := 50
@export_range(0, 1000, 1) var magic_power_price := 50
@export_range(0, 1000, 1) var healing_power_price := 45
@export_range(0, 1000, 1) var refresh_base_price := 15
@export_range(0, 1000, 1) var refresh_price_increment := 10


func enemy_health(battle_number: int, is_boss: bool = false) -> int:
	var value := float(enemy_base_health) * _battle_growth(health_growth_per_battle, battle_number) * _cycle_growth(health_growth_per_cycle, battle_number)
	return ceili(value * (boss_health_multiplier if is_boss else 1.0))


func enemy_damage(battle_number: int, is_boss: bool = false) -> int:
	var value := float(enemy_base_damage) * _battle_growth(damage_growth_per_battle, battle_number) * _cycle_growth(damage_growth_per_cycle, battle_number)
	return ceili(value * (boss_damage_multiplier if is_boss else 1.0))


func enemy_experience(battle_number: int) -> int:
	return ceili(float(enemy_base_experience) * _battle_growth(experience_growth_per_battle, battle_number))


func enemy_coins(battle_number: int) -> int:
	return enemy_base_coins + floori(float(battle_number) / float(coin_battle_interval))


func scaled_price(base_price: int, defeated_bosses: int) -> int:
	assert(base_price >= 0 and defeated_bosses >= 0, "Price scaling requires non-negative values")
	var raw_price := float(base_price) * pow(1.0 + price_growth_per_boss, defeated_bosses)
	return ceili(raw_price / float(price_rounding_step)) * price_rounding_step


func _battle_growth(rate: float, battle_number: int) -> float:
	assert(battle_number >= 1, "Battle number starts at one")
	return pow(1.0 + rate, battle_number - 1)


func _cycle_growth(rate: float, battle_number: int) -> float:
	return pow(1.0 + rate, floori(float(battle_number - 1) / float(battles_per_cycle)))
