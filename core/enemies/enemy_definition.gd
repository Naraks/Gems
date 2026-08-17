class_name EnemyDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var archetype: String
@export_enum("Physical:0", "Magic:1") var weakness_type := 0
@export var intent_cycle: PackedInt32Array = []
@export var intent_multipliers: PackedFloat32Array = []
@export var special_title := "Особое действие"
@export_range(0, 12, 1) var special_value := 0


func is_valid() -> bool:
	return (
		not id.is_empty()
		and not display_name.is_empty()
		and intent_cycle.size() > 0
		and intent_cycle.size() == intent_multipliers.size()
	)
