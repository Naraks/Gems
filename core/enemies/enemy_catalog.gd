class_name EnemyCatalog
extends RefCounted

const BIOMES := [&"ruins", &"mines", &"tower"]
const PATHS := {
	&"ruins": [
		"res://data/enemies/ruins_fighter.tres", "res://data/enemies/ruins_healer.tres", "res://data/enemies/ruins_curser.tres", "res://data/enemies/ruins_berserker.tres", "res://data/enemies/ruins_shieldbearer.tres",
		"res://data/enemies/ruins_duelist.tres", "res://data/enemies/ruins_mender.tres", "res://data/enemies/ruins_hexer.tres", "res://data/enemies/ruins_rager.tres", "res://data/enemies/ruins_warden.tres",
	],
	&"mines": [
		"res://data/enemies/mines_fighter.tres", "res://data/enemies/mines_healer.tres", "res://data/enemies/mines_curser.tres", "res://data/enemies/mines_berserker.tres", "res://data/enemies/mines_shieldbearer.tres",
		"res://data/enemies/mines_duelist.tres", "res://data/enemies/mines_mender.tres", "res://data/enemies/mines_hexer.tres", "res://data/enemies/mines_rager.tres", "res://data/enemies/mines_warden.tres",
	],
	&"tower": [
		"res://data/enemies/tower_fighter.tres", "res://data/enemies/tower_healer.tres", "res://data/enemies/tower_curser.tres", "res://data/enemies/tower_berserker.tres", "res://data/enemies/tower_shieldbearer.tres",
		"res://data/enemies/tower_duelist.tres", "res://data/enemies/tower_mender.tres", "res://data/enemies/tower_hexer.tres", "res://data/enemies/tower_rager.tres", "res://data/enemies/tower_warden.tres",
	],
}


func all() -> Array[Resource]:
	var definitions: Array[Resource] = []
	for biome in BIOMES:
		definitions.append_array(for_biome(biome))
	return definitions


func for_biome(biome_id: StringName) -> Array[Resource]:
	assert(PATHS.has(biome_id), "Unknown enemy biome")
	var definitions: Array[Resource] = []
	for path in PATHS[biome_id]:
		definitions.append(load(path))
	return definitions


func for_battle(battle_number: int) -> Resource:
	assert(battle_number >= 1, "Battle number starts at one")
	var cycle_battle := (battle_number - 1) % 30
	var biome_index := floori(float(cycle_battle) / 10.0)
	var biome: StringName = BIOMES[biome_index]
	return for_biome(biome)[cycle_battle % 10]
