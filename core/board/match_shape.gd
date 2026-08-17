class_name MatchShape
extends RefCounted

enum Value {
	LINE_3,
	LINE_4,
	T_OR_L,
	LINE_5_PLUS,
}


static func multiplier(shape: int) -> float:
	match shape:
		Value.LINE_3:
			return 1.0
		Value.LINE_4:
			return 1.75
		Value.T_OR_L:
			return 2.25
		Value.LINE_5_PLUS:
			return 2.75
		_:
			return 0.0
