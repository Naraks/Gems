class_name ShopScreen
extends Control

signal closed

const ShopStateScript = preload("res://core/shop/shop_state.gd")

@onready var coins_label: Label = %ShopCoinsLabel
@onready var item_buttons: Array[Button] = [%ShopItem1, %ShopItem2, %ShopItem3, %ShopItem4]
@onready var refresh_button: Button = %RefreshButton
@onready var leave_button: Button = %LeaveButton

var shop: RefCounted


func _ready() -> void:
	for index in item_buttons.size():
		item_buttons[index].pressed.connect(_purchase.bind(index))
	refresh_button.pressed.connect(_refresh)
	leave_button.pressed.connect(func() -> void: closed.emit())


func setup(hero: RefCounted, seed: int = 0, defeated_bosses: int = 0) -> void:
	shop = ShopStateScript.new(hero, seed, defeated_bosses)
	_refresh_ui()


func _purchase(index: int) -> void:
	if shop != null:
		shop.purchase(index)
		_refresh_ui()


func _refresh() -> void:
	if shop != null:
		shop.refresh()
		_refresh_ui()


func _refresh_ui() -> void:
	if shop == null or not is_node_ready():
		return
	coins_label.text = "Монеты: %d" % shop.hero.coins
	for index in item_buttons.size():
		var item = shop.items[index]
		item_buttons[index].text = "%s\n%s\n%d монет%s" % [
			item.title,
			item.description,
			item.price,
			"\nКУПЛЕНО" if item.sold else "",
		]
		item_buttons[index].disabled = not shop.can_purchase(index)
	refresh_button.text = "Обновить · %d" % shop.refresh_cost
	refresh_button.disabled = not shop.can_refresh()
