extends Node
# Dictionary to store all item types by name for easy lookup
var available_items: Dictionary = {}
var bonus_applied: bool = false

var crafting_recipes: Dictionary = {}  # [recipe_key: String] -> CraftingRecipe
var golden_item_registry: Dictionary = {}  # [common_item_name: String] -> golden_item_name: String
var diamond_item_registry: Dictionary = {}  # [golden_item_name: String] -> diamond_item_name: String


func _ready():
	# Create all your item types
	setup_items()
	register_golden_items()
	register_diamond_items()
	setup_crafting_system()

func setup_crafting_system():
	"""Initialize crafting recipes and upgrade paths"""
	print("Setting up crafting system...")
	setup_golden_upgrade_recipes()
	setup_diamond_upgrade_recipes()
	print("Crafting system ready. Recipes: ", crafting_recipes.size())


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

	# --- GOLDEN COMMON ITEMS
	available_items["Golden Testing Boots"] = preload("res://Resources/Items/Golden/golden_testing_boots.tres")
	available_items["Golden Testing Shield"] = preload("res://Resources/Items/Golden/golden_testing_shield.tres")
	available_items["Golden Testing Robes"] = preload("res://Resources/Items/Golden/golden_testing_robes.tres")
	
func register_golden_items():
	# -- Register all golden tier items
	# Add golden versions of your common items
	# Example format:
	# available_items["Golden [ItemName]"] = preload("res://Resources/Items/GOLDEN/golden_[itemname].tres")
	
	# TODO: Add your golden items here as you create them
	# available_items["Golden Basic Sword"] = preload("res://Resources/Items/GOLDEN/golden_basic_sword.tres")
	# available_items["Golden Leather Armor"] = preload("res://Resources/Items/GOLDEN/golden_leather_armor.tres")
	
	pass  # Remove this once you add items

func register_diamond_items():
	# -- Register all diamond tier items
	# Add golden versions of your common items
	# Example format:
	# available_items["Golden [ItemName]"] = preload("res://Resources/Items/GOLDEN/golden_[itemname].tres")
	
	# TODO: Add your golden items here as you create them
	# available_items["Golden Basic Sword"] = preload("res://Resources/Items/GOLDEN/golden_basic_sword.tres")
	# available_items["Golden Leather Armor"] = preload("res://Resources/Items/GOLDEN/golden_leather_armor.tres")
	
	pass  # Remove this once you add items	

func setup_golden_upgrade_recipes():
	"""Create upgrade recipes for Common → Golden (auto-generated)"""
	var recipe_count = 0
	
	for item_name in available_items.keys():
		var item = available_items[item_name]
		if item.rarity == Enums.Rarity.COMMON:
			var golden_name = "Golden " + item_name
			
			# Check if golden version exists
			if available_items.has(golden_name):
				# Register the upgrade path
				golden_item_registry[item_name] = golden_name
				
				# Create recipe
				var recipe = CraftingRecipe.new()
				recipe.recipe_name = item_name + " → " + golden_name
				recipe.recipe_type = CraftingRecipe.RecipeType.SAME_ITEM_UPGRADE
				recipe.ingredient_1_name = item_name
				recipe.ingredient_2_name = item_name
				recipe.result_item_name = golden_name
				recipe.requires_same_items = true
				
				# Store recipe with consistent key
				var recipe_key = generate_recipe_key(item_name, item_name)
				crafting_recipes[recipe_key] = recipe
				recipe_count += 1
				
				print("  Created recipe: 2x ", item_name, " → ", golden_name)
	
	print("Generated ", recipe_count, " golden upgrade recipes")

func setup_diamond_upgrade_recipes():
	"""Create upgrade recipes for Golden → Diamond (auto-generated)"""
	var recipe_count = 0
	
	for item_name in available_items.keys():
		var item = available_items[item_name]
		if item.rarity == Enums.Rarity.GOLDEN:
			# Diamond name is just replace "Golden" with "Diamond"
			var diamond_name = item_name.replace("Golden ", "Diamond ")
			
			# Check if diamond version exists
			if available_items.has(diamond_name):
				# Register the upgrade path
				diamond_item_registry[item_name] = diamond_name
				
				# Create recipe
				var recipe = CraftingRecipe.new()
				recipe.recipe_name = item_name + " → " + diamond_name
				recipe.recipe_type = CraftingRecipe.RecipeType.SAME_ITEM_UPGRADE
				recipe.ingredient_1_name = item_name
				recipe.ingredient_2_name = item_name
				recipe.result_item_name = diamond_name
				recipe.requires_same_items = true
				
				# Store recipe
				var recipe_key = generate_recipe_key(item_name, item_name)
				crafting_recipes[recipe_key] = recipe
				recipe_count += 1
				
				print("  Created recipe: 2x ", item_name, " → ", diamond_name)
	
	print("Generated ", recipe_count, " diamond upgrade recipes")

func generate_recipe_key(item1_name: String, item2_name: String) -> String:
	"""Generate a consistent key for recipe lookup"""
	# Sort names alphabetically to ensure "Sword+Shield" == "Shield+Sword"
	var names = [item1_name, item2_name]
	names.sort()
	return names[0] + "+" + names[1]

func can_craft_items(item1: Item, item2: Item) -> bool:
	"""Check if two items can be crafted together"""
	if not item1 or not item2:
		return false
	
	var recipe_key = generate_recipe_key(item1.item_name, item2.item_name)
	
	if crafting_recipes.has(recipe_key):
		var recipe = crafting_recipes[recipe_key]
		return recipe.validate_ingredients(item1, item2)
	
	return false

func craft_items(item1: Item, item2: Item) -> Item:
	"""Craft two items together and return the result (doesn't modify inventory)"""
	if not can_craft_items(item1, item2):
		push_error("Cannot craft these items together: " + item1.item_name + " + " + item2.item_name)
		return null
	
	var recipe_key = generate_recipe_key(item1.item_name, item2.item_name)
	var recipe = crafting_recipes[recipe_key]
	
	return recipe.get_result_item()

func get_golden_version(common_item_name: String) -> Item:
	"""Get the golden version of a common item"""
	if golden_item_registry.has(common_item_name):
		return get_item(golden_item_registry[common_item_name])
	return null

func get_diamond_version(golden_item_name: String) -> Item:
	"""Get the diamond version of a golden item"""
	if diamond_item_registry.has(golden_item_name):
		return get_item(diamond_item_registry[golden_item_name])
	return null

func get_all_craftable_items() -> Array[Item]:
	"""Get all items that can be used in crafting"""
	var craftable: Array[Item] = []
	for item in available_items.values():
		if item.rarity == Enums.Rarity.COMMON or item.rarity == Enums.Rarity.GOLDEN:
			craftable.append(item)
	return craftable


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

func get_random_items(count: int, rarity: Enums.Rarity, include_bonus: bool = false) -> Array[Item]:
	var subset_items: Array[Item] = []
	var all_items = get_all_items()
	
	# Filter for common rarity only
	for item in all_items:
		if item.rarity == rarity and item.unlocked:
			item.slot_index = 100 #set a larger slot number so tooltips generate right-side
			subset_items.append(item)
	
	# Pick random items (without duplicates)
	var selected: Array[Item] = []
	for i in count:
		if subset_items.size() > 0:
			var random_item = subset_items.pick_random()
			selected.append(random_item)
			subset_items.erase(random_item)  # Remove to avoid duplicates

	# include bonus item of higher rarity
	if include_bonus && !bonus_applied && count > 1:
		selected.append(get_item_of_higher_tier(rarity))
	return selected

func get_item_of_higher_tier(rarity: Enums.Rarity) -> Item:
	var _item: Item = null

	match rarity:
		Enums.Rarity.COMMON:
			_item = get_random_items(1, Enums.Rarity.UNCOMMON, false)[0]
		Enums.Rarity.UNCOMMON:
			_item = get_random_items(1, Enums.Rarity.RARE, false)[0]
		Enums.Rarity.RARE:
			_item = get_random_items(1, Enums.Rarity.LEGENDARY, false)[0]
		Enums.Rarity.LEGENDARY:
			_item = get_random_items(1, Enums.Rarity.MYSTERIOUS, false)[0]
		_:
			_item = get_random_items(1, Enums.Rarity.RARE, false)[0]

	bonus_applied = true
	return _item

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
	bonus_applied = false

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
