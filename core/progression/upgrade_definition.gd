class_name UpgradeDefinition
extends RefCounted

enum Id {
	TEMPERED_BLADE,
	MAGE_FOCUS,
	VITAL_BLOOD,
	ENDURANCE,
	TREASURE_HUNTER,
	COMBO_MASTER,
	LAST_CHANCE,
	WEAKNESS_EXPERT,
}

enum Rarity {
	COMMON,
	RARE,
}

var id: Id
var title: String
var description: String
var rarity: Rarity


func _init(upgrade_id: Id, upgrade_title: String, upgrade_description: String, upgrade_rarity: Rarity) -> void:
	id = upgrade_id
	title = upgrade_title
	description = upgrade_description
	rarity = upgrade_rarity


func rarity_name() -> String:
	return "Редкая" if rarity == Rarity.RARE else "Обычная"
