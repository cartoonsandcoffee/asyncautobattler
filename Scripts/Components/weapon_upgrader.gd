class_name WeaponUpgrader
extends Control

signal item_selected(Item)
signal upgrader_closed()

@onready var upgrade_container: GridContainer = $Panel/panelBlack/panelBorder/upgradeBox/upgradesGrid
@onready var name_label: Label = $Panel/panelBlack/panelBorder/upgradeBox/lblName
@onready var dialogue_label: Label = $Panel/panelBlack/panelBorder/upgradeBox/lblDesc
@onready var btn_cancel: Button = $Panel/panelBlack/panelBorder/upgradeBox/btnDone
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@export var items_offered: int = 2

@export var box_name:String = "Upgrade  Your  Weapon?"
@export_multiline var box_desc:String = "Would you like to imbue your weapon with an additioanl ability? "

var item_choice_scene = preload("res://Scenes/item_choice.tscn")
var empty_item = preload("res://Scenes/Elements/empty_choice.tscn")

var offered_upgrades: Array[Item] = []
var is_store_open: bool = false

func _ready() -> void:
	upgrade_container.columns = items_offered
	add_to_group("item_selection_events") 
	generate_item_choices()
	setup_labels()

func setup_labels():
	name_label.text = box_name
	dialogue_label.text = box_desc
	if box_desc == "" || box_desc == null:
		dialogue_label.visible = false

func generate_item_choices():
	#clear old items
	for child in upgrade_container.get_children():
		child.queue_free()
		
	# Get 3 random items
	offered_upgrades = ItemsManager.get_random_upgrades(items_offered)
	
	# Create choice buttons for each item
	for item in offered_upgrades:
		var choice_button = item_choice_scene.instantiate()
		choice_button.custom_minimum_size = Vector2(110, 140)
		upgrade_container.add_child(choice_button)
		choice_button.set_item(item)
		choice_button.setup_for_store(false)
		choice_button.item_purchased.connect(_on_item_selected)
	
	check_affordability()

func _on_item_selected(item: ItemChoice):
	purchase_item_from_store(item)

func _on_btn_done_pressed() -> void:
	hide_store()


func show_store():
	anim_player.play("show_popup")
	var anim_length = anim_player.get_animation("show_popup").length
	await CombatSpeed.create_timer(anim_length)
	is_store_open = true
	Player.popup_open = true

func hide_store():
	AudioManager.play_ui_sound("popup_close")
	anim_player.play("hide_popup")
	var anim_length = anim_player.get_animation("hide_popup").length
	await CombatSpeed.create_timer(anim_length)	
	is_store_open = false
	Player.popup_open = false
	upgrader_closed.emit()

func replace_item_with_empty(target_item: Item):
	var children = upgrade_container.get_children()
	
	for i in range(children.size()):
		var item_slot = children[i]
		
		# Check if this slot contains the target item
		if item_slot.has_method("get_current_item") and item_slot.get_current_item() == target_item:
			# Remove the old slot
			upgrade_container.remove_child(item_slot)
			item_slot.queue_free()
			
			# Create and add empty slot
			var empty_slot = empty_item.instantiate()
			empty_slot.custom_minimum_size = item_slot.custom_minimum_size  # Keep same size
			upgrade_container.add_child(empty_slot)
			
			# Move to correct position in grid
			upgrade_container.move_child(empty_slot, i)
		elif  item_slot.has_method("get_current_item") and item_slot.get_current_item() != target_item:
			item_slot.setup_for_store(false)

func check_affordability():
	var children = upgrade_container.get_children()
	
	for i in range(children.size()):
		var item_slot = children[i]
		
		if item_slot.has_method("get_current_item"):
			if item_slot.item_cost > Player.stats.gold:
				item_slot.cannot_afford()
			else:
				item_slot.can_afford()


func purchase_item_from_store(purchased_item: ItemChoice):
	if Player.stats.gold >= purchased_item.item_cost:
		Player.subtract_gold(purchased_item.item_cost)

		Player.inventory.set_weapon_upgrade(purchased_item.current_item)
		Player.update_stats_from_items()
		AudioManager.play_ui_sound("item_pickup")
		item_selected.emit(purchased_item.current_item)
		replace_item_with_empty(purchased_item.current_item)

		check_affordability()
