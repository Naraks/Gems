class_name RelicDefinition
extends RefCounted

enum Id {
	RUBY_HILT,
	SAPPHIRE_LENS,
	HEALER_FLASK,
	PROSPECTOR_HAMMER,
	MIRROR_SHARD,
	CASCADE_CLOVER,
}

var id: Id
var title: String
var description: String
var price: int


func _init(relic_id: Id, relic_title: String, relic_description: String, relic_price: int) -> void:
	id = relic_id
	title = relic_title
	description = relic_description
	price = relic_price
