class_name ShopState
extends RefCounted

const ShopItemScript = preload("res://core/shop/shop_item.gd")
const RelicCatalogScript = preload("res://core/progression/relic_catalog.gd")

var hero: RefCounted
var items: Array[RefCounted] = []
var refresh_cost := 15
var _random := RandomNumberGenerator.new()
var _relic_catalog := RelicCatalogScript.new()


func _init(hero_state: RefCounted, seed: int = 0) -> void:
	assert(hero_state != null, "Shop requires hero state")
	hero = hero_state
	if seed == 0:
		_random.randomize()
	else:
		_random.seed = seed
	_generate_items()


func can_purchase(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	var item = items[index]
	if item.sold or hero.coins < item.price:
		return false
	if item.kind in [ShopItemScript.Kind.SMALL_HEAL, ShopItemScript.Kind.FULL_HEAL] and hero.health >= hero.max_health:
		return false
	if item.kind == ShopItemScript.Kind.RELIC and (item.relic == null or hero.has_relic(item.relic.id)):
		return false
	return true


func purchase(index: int) -> bool:
	if not can_purchase(index):
		return false
	var item = items[index]
	hero.coins -= item.price
	_apply(item)
	item.sold = true
	return true


func can_refresh() -> bool:
	return hero.coins >= refresh_cost


func refresh() -> bool:
	if not can_refresh():
		return false
	hero.coins -= refresh_cost
	refresh_cost += 10
	_generate_items()
	return true


func _generate_items() -> void:
	items.clear()
	if _random.randi() % 2 == 0:
		items.append(ShopItemScript.new(ShopItemScript.Kind.SMALL_HEAL, "Малое лечение", "+25 HP", 20))
	else:
		items.append(ShopItemScript.new(ShopItemScript.Kind.FULL_HEAL, "Полное лечение", "Восстановить полное HP", 55))
	var upgrades: Array[RefCounted] = [
		ShopItemScript.new(ShopItemScript.Kind.FORTIFY, "Укрепление", "Max HP +15 и лечение на 15", 60),
		ShopItemScript.new(ShopItemScript.Kind.SWORD_POWER, "Усиление меча", "Сила меча +12%", 50),
		ShopItemScript.new(ShopItemScript.Kind.MAGIC_POWER, "Усиление магии", "Сила магии +12%", 50),
		ShopItemScript.new(ShopItemScript.Kind.HEALING_POWER, "Усиление лечения", "Сила лечения +15%", 45),
	]
	for _index in 2:
		items.append(upgrades.pop_at(_random.randi_range(0, upgrades.size() - 1)))
	var relics := _relic_catalog.available_for(hero)
	if relics.is_empty():
		items.append(ShopItemScript.new(ShopItemScript.Kind.RELIC, "Реликвии собраны", "Нет новых реликвий", 0))
	else:
		var relic = relics[_random.randi_range(0, relics.size() - 1)]
		items.append(ShopItemScript.new(ShopItemScript.Kind.RELIC, relic.title, relic.description, relic.price, relic))


func _apply(item: RefCounted) -> void:
	match item.kind:
		ShopItemScript.Kind.SMALL_HEAL:
			hero.heal(25)
		ShopItemScript.Kind.FULL_HEAL:
			hero.heal(hero.max_health)
		ShopItemScript.Kind.FORTIFY:
			hero.max_health += 15
			hero.health += 15
		ShopItemScript.Kind.SWORD_POWER:
			hero.sword_power += 0.12
		ShopItemScript.Kind.MAGIC_POWER:
			hero.magic_power += 0.12
		ShopItemScript.Kind.HEALING_POWER:
			hero.healing_power += 0.15
		ShopItemScript.Kind.RELIC:
			hero.add_relic(item.relic.id)
