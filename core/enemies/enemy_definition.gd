class_name EnemyDefinition
extends Resource

enum SpecialBehavior { NONE, ADD_BLOCKERS, SHIELD_LAST_ATTACK }

@export var id: StringName
@export var display_name: String
@export var archetype: String
@export var biome_id: StringName
@export_range(1, 10, 1) var battle_slot := 1
@export_enum("Physical:0", "Magic:1") var weakness_type := 0
@export_enum("None:-1", "Physical:0", "Magic:1") var resistance_type := -1
@export var is_boss := false
@export var intent_cycle: PackedInt32Array = []
@export var intent_multipliers: PackedFloat32Array = []
@export var special_title := "Особое действие"
@export_range(0, 12, 1) var special_value := 0
@export var special_behavior := SpecialBehavior.NONE
@export_range(0.1, 5.0, 0.05) var health_multiplier := 1.0
@export_range(0.1, 5.0, 0.05) var damage_multiplier := 1.0
@export_range(0.1, 5.0, 0.05) var experience_multiplier := 1.0
@export_range(0, 100, 1) var coin_bonus := 0
@export_range(0.0, 1.0, 0.05) var berserk_health_threshold := 0.5
@export_range(1.0, 5.0, 0.05) var berserk_damage_multiplier := 1.5
@export_category("Visual")
@export var visual_symbol := "?"
@export var visual_color := Color("8a4b42")


func is_valid() -> bool:
	return (
		not id.is_empty()
		and not display_name.is_empty()
		and not archetype.is_empty()
		and not biome_id.is_empty()
		and intent_cycle.size() > 0
		and intent_cycle.size() == intent_multipliers.size()
		and not visual_symbol.is_empty()
		and health_multiplier > 0.0
		and damage_multiplier > 0.0
		and experience_multiplier > 0.0
		and (not is_boss or resistance_type != weakness_type)
	)
