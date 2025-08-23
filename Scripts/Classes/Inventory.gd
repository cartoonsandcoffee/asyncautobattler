# inventory.gd
class_name Inventory
extends Resource

## Manages player inventory with numbered slots for rule resolution order
## Supports weapon slot + numbered item slots

signal inventory_changed(slot: int, old_item: Item, new_item: Item)
signal weapon_changed(old_weapon: Item, new_weapon: Item)
signal item_added(item: Item, slot_index: int)
signal item_removed(item: Item, slot_index: int)
signal inventory_full(item: Item)

var weapon_slot: Item = null
var item_slots: Array[Item] = []
var max_item_slots: int = 12

func _init():
	# Initialize empty item slots
	item_slots.resize(max_item_slots)

func add_item(new_item: Item) -> bool:
	# Special handling for weapons
	if new_item.item_type == Item.ItemType.WEAPON:
		return set_weapon(new_item)
	
	# Find first empty slot
	var empty_index = get_empty_slot_index()
	if empty_index != -1:
		new_item.set_position(empty_index)
		print("adding item: ", str(empty_index))
		item_slots[empty_index] = new_item
		item_added.emit(new_item, empty_index)
		return true
	
	# Inventory full
	inventory_full.emit(new_item)
	return false

func add_item_at_slot(new_item: Item, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= item_slots.size():
		return false
	
	if item_slots[slot_index] == null:
		new_item.current_position = slot_index
		item_slots[slot_index] = new_item
		item_added.emit(new_item, slot_index)
		return true
	
	return false

func replace_item(new_item: Item, slot_index: int) -> Item:
	if slot_index < 0 or slot_index >= item_slots.size():
		return null
	
	var old_item = item_slots[slot_index]
	new_item.current_position = slot_index
	item_slots[slot_index] = new_item
	
	if old_item != null:
		item_removed.emit(old_item, slot_index)
	item_added.emit(new_item, slot_index)
	
	return old_item  # Return the replaced item

func set_weapon(new_weapon: Item) -> bool:
	if new_weapon.item_type != Item.ItemType.WEAPON:
		return false
	
	var old_weapon = weapon_slot
	weapon_slot = new_weapon
	
	if old_weapon != null:
		item_removed.emit(old_weapon, -1)  # -1 indicates weapon slot
	item_added.emit(new_weapon, -1)
	
	return true

func swap_items(index_a: int, index_b: int) -> void:
	if index_a < 0 or index_a >= item_slots.size():
		return
	if index_b < 0 or index_b >= item_slots.size():
		return
	
	var temp = item_slots[index_a]
	item_slots[index_a] = item_slots[index_b]
	item_slots[index_b] = temp

	item_slots[index_a].current_position = index_b
	item_slots[index_b].current_position = index_a

func remove_item(index: int) -> Item:
	if index < 0 or index >= item_slots.size():
		return null
	
	var item = item_slots[index]
	if item != null:
		item_slots[index] = null
		item_removed.emit(item, index)
	
	return item

func clear_slot(index: int) -> void:
	if index >= 0 and index < item_slots.size():
		var item = item_slots[index]
		if item != null:
			item_slots[index] = null
			item_removed.emit(item, index)

func get_empty_slot_index() -> int:
	for i in range(item_slots.size()):
		if item_slots[i] == null:
			return i
	return -1

func has_empty_slot() -> bool:
	return get_empty_slot_index() != -1

func is_full() -> bool:
	for slot in item_slots:
		if slot == null:
			return false
	return true

func get_item_count() -> int:
	var count = 0
	for slot in item_slots:
		if slot != null:
			count += 1
	return count

func expand_inventory(additional_slots: int) -> void:
	max_item_slots += additional_slots
	item_slots.resize(max_item_slots)

# For saving/loading
func get_save_data() -> Dictionary:
	var data = {
		"max_slots": max_item_slots,
		"items": [],
		"weapon": null
	}
	
	for i in range(item_slots.size()):
		if item_slots[i] != null:
			data.items.append({
				"slot": i,
				"item_resource_path": item_slots[i].resource_path
			})
	
	if weapon_slot != null:
		data.weapon = weapon_slot.resource_path
	
	return data

func load_from_save_data(data: Dictionary) -> void:
	max_item_slots = data.get("max_slots", 4)
	item_slots.clear()
	item_slots.resize(max_item_slots)
	
	for item_data in data.get("items", []):
		var item = load(item_data.item_resource_path) as Item
		if item:
			item_slots[item_data.slot] = item
	
	if data.has("weapon") and data.weapon != null:
		weapon_slot = load(data.weapon) as Item

func print_inventory():
	print(" ------ CURRENT INVENTORY ITEMS (SLOTS) ------")
	for i in range(item_slots.size()):
		if item_slots[i]:
			print(str(i) + ": " + item_slots[i].item_name + " (position: " + str(item_slots[i].current_position) + ")")
