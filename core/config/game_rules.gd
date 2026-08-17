class_name GameRules
extends Resource

## Product-level gameplay parameters from GDD v1.0.
## Systems consume this resource instead of reading values from UI nodes.

@export_category("Board")
@export_range(3, 12, 1) var board_columns: int = 7
@export_range(3, 12, 1) var board_rows: int = 7
@export_range(3, 8, 1) var minimum_match_size: int = 3
@export_range(0, 49, 1) var maximum_empty_stones: int = 12

@export_category("Generator weights")
@export_range(0.0, 1.0, 0.01) var sword_weight: float = 0.24
@export_range(0.0, 1.0, 0.01) var magic_weight: float = 0.24
@export_range(0.0, 1.0, 0.01) var heart_weight: float = 0.20
@export_range(0.0, 1.0, 0.01) var coin_weight: float = 0.18
@export_range(0.0, 1.0, 0.01) var empty_stone_weight: float = 0.14

@export_category("Base effects")
@export_range(0, 1000, 1) var base_physical_damage: int = 10
@export_range(0, 1000, 1) var base_magic_damage: int = 10
@export_range(0, 1000, 1) var base_healing: int = 8
@export_range(0, 1000, 1) var base_coins: int = 3

@export_category("Hero")
@export_range(1, 10000, 1) var hero_max_health: int = 100
@export_range(0.0, 10.0, 0.01) var hero_sword_power: float = 1.0
@export_range(0.0, 10.0, 0.01) var hero_magic_power: float = 1.0
@export_range(0.0, 10.0, 0.01) var hero_healing_power: float = 1.0
@export_range(0.0, 10.0, 0.01) var hero_coin_multiplier: float = 1.0

@export_category("Combat")
@export_range(1, 10000, 1) var enemy_base_health: int = 45
@export_range(0, 1000, 1) var enemy_base_damage: int = 8
@export_range(1.0, 10.0, 0.05) var weakness_multiplier: float = 1.5
@export_range(0.0, 1.0, 0.05) var boss_resistance_multiplier: float = 0.65
@export_range(1, 100, 1) var boss_interval: int = 10


func board_size() -> Vector2i:
	return Vector2i(board_columns, board_rows)


func generator_weight_total() -> float:
	return sword_weight + magic_weight + heart_weight + coin_weight + empty_stone_weight


func is_valid() -> bool:
	return (
		board_columns >= minimum_match_size
		and board_rows >= minimum_match_size
		and maximum_empty_stones < board_columns * board_rows
		and is_equal_approx(generator_weight_total(), 1.0)
		and hero_max_health > 0
		and enemy_base_health > 0
		and boss_interval > 0
	)
