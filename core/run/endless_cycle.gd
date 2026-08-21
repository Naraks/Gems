class_name EndlessCycle
extends RefCounted

const BATTLES_PER_BIOME := 10
const BATTLES_PER_CYCLE := 30
const BIOME_IDS := [&"ruins", &"mines", &"tower"]
const BIOME_NAMES := {
	&"ruins": "Заросшие руины",
	&"mines": "Пепельные шахты",
	&"tower": "Башня безмолвия",
}
const MAX_BLOCKER_BONUS := 6


static func cycle_index(battle_number: int) -> int:
	assert(battle_number >= 1, "Battle number starts at one")
	return (battle_number - 1) / BATTLES_PER_CYCLE


static func cycle_number(battle_number: int) -> int:
	return cycle_index(battle_number) + 1


static func biome_index(battle_number: int) -> int:
	assert(battle_number >= 1, "Battle number starts at one")
	return ((battle_number - 1) % BATTLES_PER_CYCLE) / BATTLES_PER_BIOME


static func biome_id(battle_number: int) -> StringName:
	return BIOME_IDS[biome_index(battle_number)]


static func biome_name(battle_number: int) -> String:
	return BIOME_NAMES[biome_id(battle_number)]


static func battle_in_biome(battle_number: int) -> int:
	assert(battle_number >= 1, "Battle number starts at one")
	return (battle_number - 1) % BATTLES_PER_BIOME + 1


static func blocker_limit_bonus(battle_number: int) -> int:
	return mini(cycle_index(battle_number), MAX_BLOCKER_BONUS)


static func modifier_text(battle_number: int) -> String:
	var bonus := blocker_limit_bonus(battle_number)
	if bonus == 0:
		return ""
	return "Цикл %d · лимит пустых камней +%d" % [cycle_number(battle_number), bonus]


static func palette_hue_shift(battle_number: int) -> float:
	return fmod(float(cycle_index(battle_number)) * 0.035, 0.21)
