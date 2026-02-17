extends Node
# Dictionary to store all item types by name for easy lookup
var available_items: Dictionary = {}

var crafting_recipes: Array[CraftingRecipe] = []  # [recipe_key: String] -> CraftingRecipe
var golden_item_registry: Dictionary = {}  # [common_item_name: String] -> golden_item_name: String
var diamond_item_registry: Dictionary = {}  # [golden_item_name: String] -> diamond_item_name: String

var _initialized: bool = false

func _ready():
	pass

func initialize():
	if _initialized:
		return

	_initialized = true

	# MOVED FROM _READY()
	# Create all your item types
	crafting_recipes.clear()

	setup_items()
	setup_crafting_recipes()


func setup_crafting_recipes():
	get_all_crafting_recipes_from_directory("res://Resources/CraftingRecipes/", ".tres")

func setup_items():
	get_all_files_from_directory("res://Resources/Items/", ".tres")


func can_craft_items(item1: Item, item2: Item) -> bool:
	"""Check if two items can be crafted together"""
	if not item1 or not item2:
		return false
	
	for recipe in crafting_recipes:
		if recipe.validate_ingredients(item1, item2):
			return true
		
	return false

func craft_items(item1: Item, item2: Item) -> Item:
	# Craft two items together and return the result (doesn't modify inventory)
	if not can_craft_items(item1, item2):
		push_error("Cannot craft these items together: " + item1.item_name + " + " + item2.item_name)
		return null
	
	for recipe in crafting_recipes:
		if recipe.validate_ingredients(item1, item2):
			return recipe.get_result_item()
	
	return null


func get_all_craftable_items() -> Array[Item]:
	"""Get all items that can be used in crafting"""
	var craftable: Array[Item] = []
	for item in available_items.values():
		if item.rarity == Enums.Rarity.DIAMOND or item.rarity == Enums.Rarity.GOLDEN or item.rarity == Enums.Rarity.CRAFTED:
			craftable.append(item)
	return craftable


func get_item(item_name: String) -> Item:
	# Get a specific item by name
	if available_items.has(item_name):
		return available_items[item_name]
	else:
		push_warning("[ItemsManager] item not found: ", item_name)
		return null

func get_item_picture(item_name: String) -> Texture2D:
	if available_items.has(item_name):
		return available_items[item_name].item_icon
	else:
		push_warning("[ItemsManager] Item picture not found: ", item_name)
		return null

func get_all_items() -> Array[Item]:
	# Get all available items (useful for shop UI)
	var items: Array[Item] = []
	for item in available_items.values():
		items.append(item)
		
	# sort by rarity
	items.sort_custom(func(a, b): return a.rarity < b.rarity)
	return items

func get_random_items(count: int, rarity: Enums.Rarity, include_bonus: bool = false, include_weapons: bool = false, max_1_weapon: bool = false) -> Array[Item]:
	var subset_items: Array[Item] = []
	var all_items = get_all_items()
	var wep_count: int = 0

	# Filter for common rarity only
	for item in all_items:
		if item.rarity == rarity and item.unlocked:
			if include_weapons:	
				if item.item_name == Player.inventory.weapon_slot.item_name:  # Don't offer player weapon they already have.
					continue
				if item.has_category("Unique") && Player.inventory.has_unique_item(item.item_id): # Don't offer player multiple copies of unique items
					continue
				if item.has_category("Singularity") && Player.inventory.has_any_singularity_item(): # Don't offer player singularity items if they have one
					continue
				subset_items.append(item)
			else:
				# exclude weapons
				if item.item_type == Item.ItemType.WEAPON:
					pass
				else:
					subset_items.append(item)
	
	# Pick random items (without duplicates)
	var selected: Array[Item] = []
	var attempts: int = 0
	var max_attempts: int = count * 10  # Safety limit

	while selected.size() < count and subset_items.size() > 0 and attempts < max_attempts:
		attempts += 1
		var random_item = subset_items.pick_random()

		# If limiting weapons, check if we already have one
		if max_1_weapon and random_item.item_type == Item.ItemType.WEAPON:
			if wep_count >= 1:
				# Skip this weapon, try again
				subset_items.erase(random_item)
				continue
			else:
				wep_count += 1

		selected.append(random_item)
		subset_items.erase(random_item)  # Remove to avoid duplicates

	# include bonus item of higher rarity
	if include_bonus && count > 1:
		selected.append(get_item_of_higher_tier(rarity))
	return selected


func get_items_by_item_type(count: int, _item_type: Item.ItemType, _limit_rarity: bool = false, _rarity: Enums.Rarity = Enums.Rarity.COMMON):
	var subset_items: Array[Item] = []
	var all_items = get_all_items()
	
	# Filter for common rarity only
	for item in all_items:
		if item.item_type == _item_type:
			if _limit_rarity and item.rarity == _rarity:
				if item.item_name == "Bare Fists":
					continue
				subset_items.append(item)
			elif !_limit_rarity:
				if item.rarity in [Enums.Rarity.COMMON, Enums.Rarity.UNCOMMON, Enums.Rarity.RARE]:
					if item.has_category("Unique") && Player.inventory.has_unique_item(item.item_id): # Don't offer player multiple copies of unique items
						continue
					if item.has_category("Singularity") && Player.inventory.has_any_singularity_item(): # Don't offer player singularity items if they have one
						continue					
					subset_items.append(item)	

	# Pick random items (without duplicates)
	var selected: Array[Item] = []
	for i in count:
		if subset_items.size() > 0:
			var random_item = subset_items.pick_random()
			selected.append(random_item)
			subset_items.erase(random_item)  # Remove to avoid duplicates

	return selected

func get_items_by_category(count: int, _category: String):
	var subset_items: Array[Item] = []
	var all_items = get_all_items()
	
	# Filter for common rarity only
	for item in all_items:
		for cat in item.categories:
			if cat == _category:
				if item.rarity in [Enums.Rarity.COMMON, Enums.Rarity.UNCOMMON, Enums.Rarity.RARE]:
					if item.has_category("Unique") && Player.inventory.has_unique_item(item.item_id): # Don't offer player multiple copies of unique items
						continue
					if item.has_category("Singularity") && Player.inventory.has_any_singularity_item(): # Don't offer player singularity items if they have one
						continue					
					subset_items.append(item)

	# Pick random items (without duplicates)
	var selected: Array[Item] = []
	for i in count:
		if subset_items.size() > 0:
			var random_item = subset_items.pick_random()
			selected.append(random_item)
			subset_items.erase(random_item)  # Remove to avoid duplicates

	return selected

func get_item_of_same_tier(rarity: Enums.Rarity, item_name: String) -> Item:
	var _item: Item = null

	_item = get_random_items(1, rarity, false, false)[0]

	while _item.item_name == item_name:
		_item = get_random_items(1, rarity, false, false)[0]
		
	return _item	

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

func get_item_by_id(item_id: String) -> Item:
	for item_name in available_items:
		var item = available_items[item_name]
		if item.item_id == item_id:
			return item
	if available_items.has(item_id):
		return available_items[item_id]
	return null

func get_all_files_from_directory(path : String, file_ext:= "", files := []):
	var resources = ResourceLoader.list_directory(path)
	for res in resources:
		#print(str(path+res))
		if res.ends_with("/"): 
			# recursive for sub-directories
			get_all_files_from_directory(path+res, file_ext, files)		
		elif file_ext && res.ends_with(file_ext): 
			files.append(path+res)
			var item = load(path+res) as Item
			if item:
				var key: String = res.replace(".tres", "")
				item.item_id = key
				available_items[key] = item
				#print("[ItemsManager] Loaded item: ", key)
			else:
				push_warning("[ItemsManager] Failed to load item: " + res)	
	return files

func get_all_crafting_recipes_from_directory(path : String, file_ext:= "", files := []):
	var resources = ResourceLoader.list_directory(path)
	for res in resources:
		#print(str(path+res))
		if res.ends_with("/"): 
			# recursive for sub-directories
			get_all_crafting_recipes_from_directory(path+res, file_ext, files)
		elif file_ext && res.ends_with(file_ext): 
			files.append(path+res)
			var recipe = load(path+res) as CraftingRecipe
			if recipe:
				var key: String = res.replace(".tres", "")
				recipe.recipe_id = key
				crafting_recipes.append(recipe)
				#print("[ItemsManager] Loaded crafting recipe: ", key)
			else:
				push_warning("[ItemsManager] Failed to load crafting recipe: " + res)	
	return files
