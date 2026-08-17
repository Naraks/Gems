class_name UpgradeCatalog
extends RefCounted

const UpgradeDefinitionScript = preload("res://core/progression/upgrade_definition.gd")

var _random := RandomNumberGenerator.new()
var _definitions: Array[RefCounted] = []


func _init(seed: int = 0) -> void:
	if seed == 0:
		_random.randomize()
	else:
		_random.seed = seed
	_definitions = [
		UpgradeDefinitionScript.new(UpgradeDefinitionScript.Id.TEMPERED_BLADE, "Закалённый клинок", "Сила меча +15%", UpgradeDefinitionScript.Rarity.COMMON),
		UpgradeDefinitionScript.new(UpgradeDefinitionScript.Id.MAGE_FOCUS, "Фокус мага", "Сила магии +15%", UpgradeDefinitionScript.Rarity.COMMON),
		UpgradeDefinitionScript.new(UpgradeDefinitionScript.Id.VITAL_BLOOD, "Живительная кровь", "Сила лечения +18%", UpgradeDefinitionScript.Rarity.COMMON),
		UpgradeDefinitionScript.new(UpgradeDefinitionScript.Id.ENDURANCE, "Выносливость", "Максимальное HP +12 и лечение на 12", UpgradeDefinitionScript.Rarity.COMMON),
		UpgradeDefinitionScript.new(UpgradeDefinitionScript.Id.TREASURE_HUNTER, "Охотник за сокровищами", "Монеты +20%", UpgradeDefinitionScript.Rarity.COMMON),
		UpgradeDefinitionScript.new(UpgradeDefinitionScript.Id.COMBO_MASTER, "Комбо-мастер", "Каскады после первого +0,10", UpgradeDefinitionScript.Rarity.RARE),
		UpgradeDefinitionScript.new(UpgradeDefinitionScript.Id.LAST_CHANCE, "Последний шанс", "Смертельный удар один раз оставляет 1 HP", UpgradeDefinitionScript.Rarity.RARE),
		UpgradeDefinitionScript.new(UpgradeDefinitionScript.Id.WEAKNESS_EXPERT, "Эксперт слабостей", "Бонус слабости становится ×1,70", UpgradeDefinitionScript.Rarity.RARE),
	]


func all() -> Array[RefCounted]:
	return _definitions.duplicate()


func draw_three() -> Array[RefCounted]:
	var pool := _definitions.duplicate()
	var choices: Array[RefCounted] = []
	for _index in 3:
		var picked := _random.randi_range(0, pool.size() - 1)
		choices.append(pool.pop_at(picked))
	return choices


func apply(upgrade: RefCounted, hero: RefCounted) -> void:
	assert(upgrade != null and hero != null, "Upgrade application requires upgrade and hero")
	match upgrade.id:
		UpgradeDefinitionScript.Id.TEMPERED_BLADE:
			hero.sword_power += 0.15
		UpgradeDefinitionScript.Id.MAGE_FOCUS:
			hero.magic_power += 0.15
		UpgradeDefinitionScript.Id.VITAL_BLOOD:
			hero.healing_power += 0.18
		UpgradeDefinitionScript.Id.ENDURANCE:
			hero.max_health += 12
			hero.health += 12
		UpgradeDefinitionScript.Id.TREASURE_HUNTER:
			hero.coin_multiplier += 0.20
		UpgradeDefinitionScript.Id.COMBO_MASTER:
			hero.cascade_bonus += 0.10
		UpgradeDefinitionScript.Id.LAST_CHANCE:
			hero.last_chance_available = true
		UpgradeDefinitionScript.Id.WEAKNESS_EXPERT:
			hero.weakness_multiplier = 1.70
