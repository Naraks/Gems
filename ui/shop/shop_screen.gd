class_name ShopScreen
extends Control

signal closed

const ShopStateScript = preload("res://core/shop/shop_state.gd")
const LocalizationServiceScript = preload("res://core/localization/localization_service.gd")

@onready var coins_label: Label = %ShopCoinsLabel
@onready var item_buttons: Array[Button] = [%ShopItem1, %ShopItem2, %ShopItem3, %ShopItem4]
@onready var refresh_button: Button = %RefreshButton
@onready var leave_button: Button = %LeaveButton
@onready var margin: MarginContainer = $Margin
@onready var layout: VBoxContainer = $Margin/Layout
@onready var items_layout: HBoxContainer = $Margin/Layout/Items
@onready var title_label: Label = $Margin/Layout/Header/Title

var shop: RefCounted


func _ready() -> void:
	for index in item_buttons.size():
		item_buttons[index].pressed.connect(_purchase.bind(index))
	refresh_button.pressed.connect(_refresh)
	leave_button.pressed.connect(func() -> void: closed.emit())
	resized.connect(_apply_responsive_style)
	_apply_responsive_style()


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
	coins_label.text = tr("Монеты: %s") % LocalizationServiceScript.format_integer(shop.hero.coins)
	for index in item_buttons.size():
		var item = shop.items[index]
		item_buttons[index].text = tr("%s\n%s\n%s монет%s") % [
			tr(item.title),
			tr(item.description),
			LocalizationServiceScript.format_integer(item.price),
			tr("\nКУПЛЕНО") if item.sold else "",
		]
		item_buttons[index].disabled = not shop.can_purchase(index)
	refresh_button.text = tr("Обновить · %s") % LocalizationServiceScript.format_integer(shop.refresh_cost)
	refresh_button.disabled = not shop.can_refresh()


func refresh_localized_text() -> void:
	_refresh_ui()


func _apply_responsive_style() -> void:
	var compact := size.y < 300.0
	var outer_margin := 8 if compact else 24
	margin.add_theme_constant_override("margin_left", outer_margin)
	margin.add_theme_constant_override("margin_top", 6 if compact else 20)
	margin.add_theme_constant_override("margin_right", outer_margin)
	margin.add_theme_constant_override("margin_bottom", 6 if compact else 20)
	layout.add_theme_constant_override("separation", 6 if compact else 16)
	items_layout.add_theme_constant_override("separation", 6 if compact else 12)
	title_label.add_theme_font_size_override("font_size", 20 if compact else 28)
	coins_label.add_theme_font_size_override("font_size", 16 if compact else 22)
	for button in item_buttons:
		button.custom_minimum_size.y = 82.0 if compact else 140.0
