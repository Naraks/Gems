class_name AttackType
extends RefCounted

enum Kind {
	NONE = -1,
	PHYSICAL,
	MAGIC,
}


static func display_name(type: Kind) -> String:
	match type:
		Kind.PHYSICAL:
			return "меч"
		Kind.MAGIC:
			return "магия"
		_:
			return "нет"
