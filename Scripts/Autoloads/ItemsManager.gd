extends Node
# Dictionary to store all item types by name for easy lookup
var available_items: Dictionary = {}
var bonus_applied: bool = false

var crafting_recipes: Array[CraftingRecipe] = []  # [recipe_key: String] -> CraftingRecipe
var golden_item_registry: Dictionary = {}  # [common_item_name: String] -> golden_item_name: String
var diamond_item_registry: Dictionary = {}  # [golden_item_name: String] -> diamond_item_name: String


func _ready():
	# Create all your item types
	setup_items()
	setup_crafting_recipes()


func setup_crafting_recipes():
	crafting_recipes.clear()

	add_recipes_golden()

	add_recipes_diamond()

	setup_potion_recipes()

	# --- BUG RECIPES (GOLDEN)
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Golden/golden_dark_crawler.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Golden/golden_dew_fly.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Golden/golden_firefly.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Golden/golden_nimble_fly.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Golden/golden_termite.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Golden/golden_thorn_bug.tres"))
	
	# --- BUG RECIPES (DIAMOND)
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Diamond/diamond_dark_crawler.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Diamond/diamond_dew_fly.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Diamond/diamond_firefly.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Diamond/diamond_nimble_fly.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Diamond/diamond_termite.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Bugs/Diamond/diamond_thorn_bug.tres"))

func setup_potion_recipes():
	# --- GOLDEN
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Potions/Golden/golden_acrid_potion.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Potions/Golden/golden_limbering_potion.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Potions/Golden/golden_vicious_potion.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Potions/Golden/golden_essence_of_charcoal.tres"))

	# DIAMOND
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Potions/Diamond/diamond_acrid_potion.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Potions/Diamond/diamond_limbering_potion.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Potions/Diamond/diamond_vicious_potion.tres"))	
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Potions/Diamond/diamond_essence_of_charcoal.tres"))	

func setup_items():
	get_all_files_from_directory("res://Resources/Items/", ".tres")
	#_load_item_definitions(Enums.Rarity.COMMON)
	#_load_item_definitions(Enums.Rarity.UNCOMMON)
	#_load_item_definitions(Enums.Rarity.RARE)
	#_load_item_definitions(Enums.Rarity.LEGENDARY)
	#_load_item_definitions(Enums.Rarity.CRAFTED)
	#_load_item_definitions(Enums.Rarity.GOLDEN)
	#_load_item_definitions(Enums.Rarity.DIAMOND)

func add_recipes_golden():
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/golden_testing_boots.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/golden_testing_robe.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/golden_testing_shield.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/golden_liferoot_gauntlets.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/golden_thorn_shield.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_battleworn_shield.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_double_plated_armor.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_tower_shield.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_lantern.tres"))

	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_bronze_barbed_helm.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_livingwood_cloak.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_livingwood_helmet.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_thirsty_helmet.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_nimble_hood.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_peculiar_timepiece.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_purpleskin_gloves.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_purpleskin_vest.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_shafeek_boots.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Golden/golden_shafeek_shield.tres"))

func add_recipes_diamond():
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_battleworn_shield.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_double_plated_armor.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_lantern.tres"))

	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_bronze_barbed_helm.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_livingwood_cloak.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_livingwood_helmet.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_thirsty_helmet.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_nimble_hood.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_peculiar_timepiece.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_purpleskin_gloves.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_purpleskin_vest.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_shafeek_boots.tres"))
	crafting_recipes.append(preload("res://Resources/CraftingRecipes/Diamond/diamond_shafeek_shield.tres"))

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

func get_item_of_same_tier(rarity: Enums.Rarity, item_name: String) -> Item:
	var _item: Item = null

	_item = get_random_items(1, rarity, false)[0]

	while _item.item_name == item_name:
		_item = get_random_items(1, rarity, false)[0]
		
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

func get_item_by_id(item_id: String) -> Item:
	for item_name in available_items:
		var item = available_items[item_name]
		if item.item_id == item_id:
			return item
	if available_items.has(item_id):
		return available_items[item_id]
	return null

func _load_item_definitions(rarity: Enums.Rarity):
	var item_dir = "res://Resources/Items/"
	var rarity_dir: String = ""

	match rarity:
		Enums.Rarity.COMMON:
			rarity_dir = "COMMON/"
		Enums.Rarity.UNCOMMON:
			rarity_dir = "UNCOMMON/"
		Enums.Rarity.RARE:
			rarity_dir = "RARE/"
		Enums.Rarity.LEGENDARY:
			rarity_dir = "LEGENDARY/"
		Enums.Rarity.MYSTERIOUS:
			rarity_dir = "MYSTERIOUS/"
		Enums.Rarity.GOLDEN:
			rarity_dir = "Golden/"
		Enums.Rarity.DIAMOND:
			rarity_dir = "Diamond/"
		Enums.Rarity.CRAFTED:
			rarity_dir = "CRAFTED/"
		Enums.Rarity.UNIQUE:
			rarity_dir = "UNIQUE/"

	var dir = DirAccess.open(item_dir + rarity_dir)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var item_path = item_dir + rarity_dir + file_name
				var item = load(item_path) as Item
				
				if item:
					var key: String = file_name.replace(".tres", "")
					item.item_id = key
					available_items[key] = item
					print("Loaded item: ", key)
				else:
					push_warning("Failed to load item: " + file_name)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	else:
		push_error("Could not open item directory: " + item_dir + rarity_dir)

func get_all_files_from_directory(path : String, file_ext:= "", files := []):
	var resources = ResourceLoader.list_directory(path)
	for res in resources:
		print(str(path+res))
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
				print("Loaded item: ", key)
			else:
				push_warning("Failed to load item: " + res)	
	return files