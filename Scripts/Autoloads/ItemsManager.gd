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
	# Store them in our dictionary 
	# --- COMMON
	add_common_items()

	available_items["Fists"] = preload("res://Resources/Items/Weapons/weapon_fists.tres")
	available_items["Holy Shield"] = preload("res://Resources/Items/Armor/holy_shield.tres")
	available_items["Tower Shield"] = preload("res://Resources/Items/Armor/tower_shield.tres")
	available_items["Liferoot Gauntlets"] = preload("res://Resources/Items/Armor/liferoot_gauntlets.tres")
	available_items["Rusted Plate"] = preload("res://Resources/Items/Armor/rusted_plate.tres")
	available_items["Testing Boots"] = preload("res://Resources/Items/Armor/testing_boots.tres")
	available_items["Testing Shield"] = preload("res://Resources/Items/Armor/testing_shield.tres")
	available_items["Testing Robes"] = preload("res://Resources/Items/Armor/testing_robes.tres")
	available_items["Thorn Shield"] = preload("res://Resources/Items/Armor/thorn_shield.tres")
	available_items["Shield Tap"] = preload("res://Resources/Items/Armor/armor_tap.tres")
	available_items["Testing Relic"] = preload("res://Resources/Items/Armor/test_relic.tres")

	# --- UNCOMMON
	available_items["Ornate Sword"] = preload("res://Resources/Items/UNCOMMON/ornate_sword.tres")
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
	available_items["Golden Double Plated Armor"] = preload("res://Resources/Items/COMMON/double_plated_armor.tres")
	available_items["Golden Tower Shield"] = preload("res://Resources/Items/GOLDEN/golden_tower_shield.tres")
	available_items["Golden Lantern"] = preload("res://Resources/Items/GOLDEN/golden_lantern.tres")

	# --- DIAMOND COMMON ITEMS
	available_items["Diamond Battleworn Shield"] = preload("res://Resources/Items/Diamond/diamond_battleworn_shield.tres")
	available_items["Diamond Lantern"] = preload("res://Resources/Items/Diamond/diamond_lantern.tres")

	# --- RARE ITEMS
	available_items["Clearmetal Dagger"] = preload("res://Resources/Items/RARE/Clearmetal_Dagger.tres")
	available_items["Crude Staff"] = preload("res://Resources/Items/RARE/CrudeGlowingStaff.tres")
	available_items["Clearmetal Mace"] = preload("res://Resources/Items/RARE/clearmetal_mace.tres")
	available_items["Nimble Bow"] = preload("res://Resources/Items/RARE/nimble_bow.tres")
	available_items["Giants Fingernail"] = preload("res://Resources/Items/RARE/giants_fingernail.tres")
	available_items["Poison Dagger"] = preload("res://Resources/Items/RARE/poison_dagger.tres")
	available_items["Corrosive Sword"] = preload("res://Resources/Items/RARE/corrosive_sword.tres")

	# --- LEGENDARY 
	available_items["Flaming Pick"] = preload("res://Resources/Items/LEGENDARY/flaming_sword.tres")

	# --- Sample Build 1
	available_items["Clearmetal Dagger"] = preload("res://Resources/Items/RARE/Clearmetal_Dagger.tres")
	available_items["Metallic Glass"] = preload("res://Resources/Items/CRAFTED/Metallic_Glass.tres")
	available_items["Ironskin Potion"] = preload("res://Resources/Items/UNCOMMON/Ironskin_Potion.tres")
	available_items["Clearmetal Crown"] = preload("res://Resources/Items/UNCOMMON/Clearmetal_Crown.tres")
	available_items["Reinforced Gauntlets"] = preload("res://Resources/Items/UNCOMMON/reinforced_gauntlet.tres")
	available_items["Chainmail Shirt"] = preload("res://Resources/Items/UNCOMMON/Chainmail_Shirt.tres")
	available_items["Metalliglass Totem"] = preload("res://Resources/Items/RARE/Metalliglass_Totem.tres")
	available_items["Metalliglass Timepiece"] = preload("res://Resources/Items/RARE/Metalliglass_Timepiece.tres")
	available_items["Diamond Double Plated Armor"] = preload("res://Resources/Items/Diamond/diamond_double_plated_armor.tres")
	available_items["Potion of Insecurity"] = preload("res://Resources/Items/UNCOMMON/potion_insecurity.tres")
	available_items["Indecent Exposure"] = preload("res://Resources/Items/UNCOMMON/Indecent_Exposure.tres")
	available_items["Golden Battleworn Shield"] = preload("res://Resources/Items/Golden/golden_battleworn_shield.tres")
	available_items["Clearmetal Battle Horn"] = preload("res://Resources/Items/RARE/Clearmetal_Horn.tres")

	add_bug_items()
	add_potions()

func add_common_items():
	available_items["Crude Blade"] = preload("res://Resources/Items/COMMON/crude_blade.tres")
	available_items["Living Wood Club"] = preload("res://Resources/Items/COMMON/living_wood_club.tres")
	available_items["Spiked Mace"] = preload("res://Resources/Items/COMMON/spiked_mace.tres")
	available_items["Parrying Blade"] = preload("res://Resources/Items/COMMON/parrying_blade.tres")
	available_items["Thirsty Steel"] = preload("res://Resources/Items/COMMON/thirsty_blade.tres")
	available_items["Shafeek Sword"] = preload("res://Resources/Items/COMMON/shafeek_sword.tres")
	available_items["Elderwood Bow"] = preload("res://Resources/Items/COMMON/elderwood_bow.tres")
	available_items["Ikurs Spear"] = preload("res://Resources/Items/COMMON/ikur_spear.tres")
	available_items["Nimble Cutlass"] = preload("res://Resources/Items/COMMON/nimble_cutlass.tres")
	available_items["Lantern"] = preload("res://Resources/Items/COMMON/lantern.tres")
	
	available_items["Bronze Barbed Helm"] = preload("res://Resources/Items/COMMON/bronze_barbed_helm.tres")
	available_items["Livingwood Cloak"] = preload("res://Resources/Items/COMMON/living_wood_cloak.tres")
	available_items["Livingwood Helmet"] = preload("res://Resources/Items/COMMON/living_wood_helmet.tres")
	available_items["Thirsty Helmet"] = preload("res://Resources/Items/COMMON/thirsty_helmet.tres")
	available_items["Nimble Hood"] = preload("res://Resources/Items/COMMON/nimble_hood.tres")
	available_items["Peculiar Timepiece"] = preload("res://Resources/Items/COMMON/peculiar_timepiece.tres")
	available_items["Purpleskin Gloves"] = preload("res://Resources/Items/COMMON/purple_skin_gloves.tres")
	available_items["Purpleskin Vest"] = preload("res://Resources/Items/COMMON/purple_skin_vest.tres")
	available_items["Shafeeks Boots"] = preload("res://Resources/Items/COMMON/shafeek_boots.tres")
	available_items["Shafeeks Shield"] = preload("res://Resources/Items/COMMON/shafeek_shield.tres")

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

func add_potions():
	# -- COMMON
	available_items["Acrid Potion"] = preload("res://Resources/Items/POTIONS/acrid_potion.tres")
	available_items["Limbering Potion"] = preload("res://Resources/Items/POTIONS/limbering_potion.tres")
	available_items["Vicious Potion"] = preload("res://Resources/Items/POTIONS/vicious_potion.tres")
	available_items["Essence of Charcoal"] = preload("res://Resources/Items/POTIONS/essence_of_charcoal.tres")

	# -- GOLDEN
	available_items["Golden Acrid Potion"] = preload("res://Resources/Items/POTIONS/Golden/golden_acrid_potion.tres")
	available_items["Golden Limbering Potion"] = preload("res://Resources/Items/POTIONS/Golden/golden_limbering_potion.tres")
	available_items["Golden Vicious Potion"] = preload("res://Resources/Items/POTIONS/Golden/golden_vicious_potion.tres")
	available_items["Golden Essence of Charcoal"] = preload("res://Resources/Items/POTIONS/Golden/golden_essence_of_charcoal.tres")

	# -- DIAMOND
	available_items["Diamond Acrid Potion"] = preload("res://Resources/Items/POTIONS/Diamond/diamond_acrid_potion.tres")
	available_items["Diamond Limbering Potion"] = preload("res://Resources/Items/POTIONS/Diamond/diamond_limbering_potion.tres")
	available_items["Diamond Vicious Potion"] = preload("res://Resources/Items/POTIONS/Diamond/diamond_vicious_potion.tres")
	available_items["Diamond Essence of Charcoal"] = preload("res://Resources/Items/POTIONS/Diamond/diamond_essence_of_charcoal.tres")

func add_bug_items():
	# --- COMMON
	available_items["Dark Crawler"] = preload("res://Resources/Items/BUGS/dark_crawler.tres")
	available_items["Dew Fly"] = preload("res://Resources/Items/BUGS/dew_fly.tres")
	available_items["Firefly"] = preload("res://Resources/Items/BUGS/firefly.tres")
	available_items["Living Wood Termite"] = preload("res://Resources/Items/BUGS/living_wood_termite.tres")
	available_items["Nimble Fly"] = preload("res://Resources/Items/BUGS/nimble_fly.tres")
	available_items["Thorn Bug"] = preload("res://Resources/Items/BUGS/thorn_bug.tres")

	# --- GOLDEN
	available_items["Golden Dark Crawler"] = preload("res://Resources/Items/BUGS/GOLDEN/golden_dark_crawler.tres")
	available_items["Golden Dew Fly"] = preload("res://Resources/Items/BUGS/GOLDEN/golden_dew_fly.tres")
	available_items["Golden Firefly"] = preload("res://Resources/Items/BUGS/GOLDEN/golden_firefly.tres")
	available_items["Golden Living Wood Termite"] = preload("res://Resources/Items/BUGS/GOLDEN/golden_living_wood_termite.tres")
	available_items["Golden Nimble Fly"] = preload("res://Resources/Items/BUGS/GOLDEN/golden_nimble_fly.tres")
	available_items["Golden Thorn Bug"] = preload("res://Resources/Items/BUGS/GOLDEN/golden_thorn_bug.tres")

	# --- DIAMOND
	available_items["Diamond Dark Crawler"] = preload("res://Resources/Items/BUGS/DIAMOND/diamond_dark_crawler.tres")
	available_items["Diamond Dew Fly"] = preload("res://Resources/Items/BUGS/DIAMOND/diamond_dew_fly.tres")
	available_items["Diamond Firefly"] = preload("res://Resources/Items/BUGS/DIAMOND/diamond_firefly.tres")
	available_items["Diamond Living Wood Termite"] = preload("res://Resources/Items/BUGS/DIAMOND/diamond_living_wood_termite.tres")
	available_items["Diamond Nimble Fly"] = preload("res://Resources/Items/BUGS/DIAMOND/diamond_nimble_fly.tres")
	available_items["Diamond Thorn Bug"] = preload("res://Resources/Items/BUGS/DIAMOND/diamond_thorn_bug.tres")


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
