extends Node
# Dictionary to store all item types by name for easy lookup
var available_items: Dictionary = {}

func _ready():
	# Create all your item types
	setup_items()

func setup_items():
	# Store them in our dictionary 
	# --- COMMON
	available_items["Fists"] = preload("res://Resources/Items/Weapons/weapon_fists.tres")
	available_items["Ironstone Greatsword"] = preload("res://Resources/Items/Weapons/weapon_ironstone_greatsword.tres")
	available_items["Holy Shield"] = preload("res://Resources/Items/Armor/holy_shield.tres")
	available_items["Tower Shield"] = preload("res://Resources/Items/Armor/tower_shield.tres")
	available_items["Liferoot Gauntlets"] = preload("res://Resources/Items/Armor/liferoot_gauntlets.tres")
	available_items["Rusted Plate"] = preload("res://Resources/Items/Armor/rusted_plate.tres")
	available_items["Testing Boots"] = preload("res://Resources/Items/Armor/testing_boots.tres")
	available_items["Testing Shield"] = preload("res://Resources/Items/Armor/testing_shield.tres")
	available_items["Testing Robes"] = preload("res://Resources/Items/Armor/testing_robes.tres")
	available_items["Thorn Shield"] = preload("res://Resources/Items/Armor/thorn_shield.tres")
	available_items["Shield Tap"] = preload("res://Resources/Items/Armor/armor_tap.tres")

	# --- UNCOMMON
	available_items["Bramble Belt"] = preload("res://Resources/Items/UNCOMMON/bramble_belt.tres")
	available_items["Bramble Buckler"] = preload("res://Resources/Items/UNCOMMON/bramble_buckler.tres")	
	available_items["Ironstone Spear"] = preload("res://Resources/Items/UNCOMMON/ironstone_spear.tres")
	available_items["Leather Boots"] = preload("res://Resources/Items/UNCOMMON/leather_boots.tres")
	available_items["Swiftstrike Rapier"] = preload("res://Resources/Items/UNCOMMON/swiftstrike_rapier.tres")
	available_items["Weird Axe"] = preload("res://Resources/Items/UNCOMMON/weird_axe.tres")


func get_item(item_name: String) -> Item:
	# Get a specific item by name
	if available_items.has(item_name):
		return available_items[item_name]
	else:
		print("item not found: ", item_name)
		return null

func get_item_picture(item_name: String) -> Texture2D:
	if available_items.has(item_name):
		return available_items[item_name].item_icon
	else:
		print("Item not found: ", item_name)
		return null

func get_all_items() -> Array[Item]:
	# Get all available items (useful for shop UI)
	var items: Array[Item] = []
	for item in available_items.values():
		items.append(item)
		
	# sort by rarity
	items.sort_custom(func(a, b): return a.rarity < b.rarity)
	return items

func get_random_items(count: int, rarity: Enums.Rarity) -> Array[Item]:
	var common_items: Array[Item] = []
	var all_items = get_all_items()
	
	# Filter for common rarity only
	for item in all_items:
		if item.rarity == rarity and item.unlocked:
			item.slot_index = 100 #set a larger slot number so tooltips generate right-side
			common_items.append(item)
	
	# Pick random items (without duplicates)
	var selected: Array[Item] = []
	for i in count:
		if common_items.size() > 0:
			var random_item = common_items.pick_random()
			selected.append(random_item)
			common_items.erase(random_item)  # Remove to avoid duplicates
	
	return selected

func get_random_common_items(count: int) -> Array[Item]:
	var common_items: Array[Item] = []
	var all_items = get_all_items()
	
	# Filter for common rarity only
	for item in all_items:
		if item.rarity == Enums.Rarity.COMMON and item.unlocked:
			item.slot_index = 100 #set a larger slot number so tooltips generate right-side
			common_items.append(item)
	
	# Pick random items (without duplicates)
	var selected: Array[Item] = []
	for i in count:
		if common_items.size() > 0:
			var random_item = common_items.pick_random()
			selected.append(random_item)
			common_items.erase(random_item)  # Remove to avoid duplicates
	
	return selected


func reset_items():
	available_items.clear()
	setup_items()

func to_dict() -> Dictionary:
	return get_save_data()

func from_dict(d: Dictionary):
	load_from_save(d)

func get_save_data() -> Dictionary:
	var item_data := {}
	for item_name in available_items:
		var item: Item = available_items[item_name]
		var entry := {
			"path": item.resource_path,
			"unlocked": item.unlocked
		}
		item_data[item_name] = entry
	return {
		"available_items": item_data
	}

func load_from_save(save_data: Dictionary) -> void:
	if not save_data.has("available_items"):
		return
	available_items.clear()
	for item_name in save_data["available_items"].keys():
		var item_entry = save_data["available_items"][item_name]
		var path : String = item_entry.get("path", "")
		var unlocked : bool = item_entry.get("unlocked", false)
		var item: Item = load(path)
		if item:
			item.unlocked = unlocked
			available_items[item_name] = item
		else:
			push_warning("Failed to load item at path: " + path)
