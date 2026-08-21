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
			return TranslationServer.translate("меч")
		Kind.MAGIC:
			return TranslationServer.translate("магия")
		_:
			return TranslationServer.translate("нет")
