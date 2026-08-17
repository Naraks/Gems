class_name RelicCatalog
extends RefCounted

const RelicDefinitionScript = preload("res://core/progression/relic_definition.gd")

var _definitions: Array[RefCounted] = [
	RelicDefinitionScript.new(RelicDefinitionScript.Id.RUBY_HILT, "Рубиновый эфес", "Первая комбинация мечей в бою ×1,5", 55),
	RelicDefinitionScript.new(RelicDefinitionScript.Id.SAPPHIRE_LENS, "Сапфировая линза", "Первая комбинация магии в бою ×1,5", 55),
	RelicDefinitionScript.new(RelicDefinitionScript.Id.HEALER_FLASK, "Фляга лекаря", "После победы восстановить 5% max HP", 70),
	RelicDefinitionScript.new(RelicDefinitionScript.Id.PROSPECTOR_HAMMER, "Молот старателя", "Комбинации 4+ дают ещё 2 монеты", 65),
	RelicDefinitionScript.new(RelicDefinitionScript.Id.MIRROR_SHARD, "Зеркальный осколок", "Первый спецприём босса задержан на ход", 95),
	RelicDefinitionScript.new(RelicDefinitionScript.Id.CASCADE_CLOVER, "Клевер каскада", "Каскады начинаются с ×1,10", 85),
]


func all() -> Array[RefCounted]:
	return _definitions.duplicate()


func available_for(hero: RefCounted) -> Array[RefCounted]:
	var available: Array[RefCounted] = []
	for relic in _definitions:
		if not hero.has_relic(relic.id):
			available.append(relic)
	return available
