class_name TileType
extends RefCounted

enum Value {
	SWORD,
	MAGIC,
	HEART,
	COIN,
	EMPTY_STONE,
}

const COUNT := 5


static func is_valid(value: int) -> bool:
	return value >= Value.SWORD and value <= Value.EMPTY_STONE


static func can_match(value: int) -> bool:
	return is_valid(value) and value != Value.EMPTY_STONE
