extends Control

@export var rules: GameRules


func _ready() -> void:
	assert(rules != null, "Main scene requires a GameRules resource")
	assert(rules.is_valid(), "GameRules resource is invalid")
