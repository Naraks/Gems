class_name ShopItem
extends RefCounted

enum Kind {
	SMALL_HEAL,
	FULL_HEAL,
	FORTIFY,
	SWORD_POWER,
	MAGIC_POWER,
	HEALING_POWER,
	RELIC,
}

var kind: Kind
var title: String
var description: String
var price: int
var relic: RefCounted
var sold := false


func _init(item_kind: Kind, item_title: String, item_description: String, item_price: int, item_relic: RefCounted = null) -> void:
	kind = item_kind
	title = item_title
	description = item_description
	price = item_price
	relic = item_relic
