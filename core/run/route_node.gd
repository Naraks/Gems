class_name RouteNode
extends RefCounted

enum Kind {
	BATTLE,
	SHOP,
	BOSS,
}

var kind: Kind
var battle_number: int
var block_number: int


func _init(node_kind: Kind, node_battle_number: int, node_block_number: int) -> void:
	kind = node_kind
	battle_number = node_battle_number
	block_number = node_block_number
