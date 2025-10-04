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
var max_item_slots: int = 8

func _init():
	# Initialize empty item slots
	item_slots.resize(max_item_slots)

func add_item(new_item: Item) -> bool:
	var item_instance = new_item.create_instance()

	# Special handling for weapons
	if item_instance.item_type == Item.ItemType.WEAPON:
		return set_weapon(item_instance)
	
	# Find first empty slot
	var empty_index = get_empty_slot_index()
	if empty_index != -1:
		item_instance.set_position(empty_index)
		item_slots[empty_index] = item_instance
		item_added.emit(item_instance, empty_index)
		return true
	
	# Inventory full
	inventory_full.emit(item_instance)
	return false

func get_item_by_instance_id(id: int) -> Item:
	for item in item_slots:
		if item and item.instance_id == id:
			return item
	
	# Also check weapon slot
	if weapon_slot and weapon_slot.instance_id == id:
		return weapon_slot
	
	return null

func get_slot_by_instance_id(id: int) -> int:
	for i in range(item_slots.size()):
		if item_slots[i] and item_slots[i].instance_id == id:
			return i
	return -1

func add_item_at_slot(new_item: Item, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= item_slots.size():
		return false
	
	if item_slots[slot_index] == null:
		item_slots[slot_index] = new_item
		item_added.emit(new_item, slot_index)
		return true
	
	return false

func replace_item_at_slot(new_item: Item, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= item_slots.size():
		return false

	item_slots[slot_index] = new_item.duplicate()
	return true

func replace_item(new_item: Item, slot_index: int) -> Item:
	if slot_index < 0 or slot_index >= item_slots.size():
		return null
	
	var old_item = item_slots[slot_index]
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

	# UPDATE POSITIONS
	if item_slots[index_a]:
		item_slots[index_a].slot_index = index_a
	if item_slots[index_b]:
		item_slots[index_b].slot_index = index_b

func remove_item(index: int) -> Item:
	if index < 0 or index >= item_slots.size():
		return null
	
	var item = item_slots[index]
	if item != null:
		item_slots[index] = null
		item_removed.emit(item, index)
		compact_items()
	
	return item

func remove_multiple_items(indices: Array[int]) -> Array[Item]:
	# Remove multiple items by index, returns removed items
	var removed_items: Array[Item] = []
	
	# Sort indices in descending order to avoid shifting issues
	var sorted_indices = indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	
	for index in sorted_indices:
		var item = remove_item(index)
		if item:
			removed_items.append(item)
	
	# Compact to remove gaps
	compact_items()
	
	return removed_items

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

func is_slot_empty(index: int) -> bool:
	if index < 0 or index >= item_slots.size():
		return true
	return item_slots[index] == null

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

func compact_items():
	"""Removes all null gaps in the inventory by shifting items left"""
	var compacted: Array[Item] = []
	
	# Collect all non-null items
	for item in item_slots:
		if item != null:
			compacted.append(item)
	
	# Clear the array
	item_slots.clear()
	item_slots.resize(max_item_slots)
	
	# Re-add items from the beginning
	for i in range(compacted.size()):
		item_slots[i] = compacted[i]
		compacted[i].slot_index = i

func move_item_to_slot(from_index: int, to_index: int):
	if from_index < 0 or from_index >= item_slots.size():
		return
	if to_index < 0 or to_index >= item_slots.size():
		return
	
	var item = item_slots[from_index]
	if not item:
		return
	
	# Clear source slot
	item_slots[from_index] = null
	
	# Place in target slot (overwriting if needed)
	item_slots[to_index] = item
	item.slot_index = to_index

func shift_items_left(start_index: int):
	for i in range(start_index, item_slots.size() - 1):
		if item_slots[i] == null and item_slots[i + 1] != null:
			item_slots[i] = item_slots[i + 1]
			item_slots[i + 1] = null
			if item_slots[i]:
				item_slots[i].slot_index = i

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
			print(str(i) + ": " + item_slots[i].item_name + " (slot: " + str(item_slots[i].slot_index) + " - id #" + str(item_slots[i].instance_id) + ")")
