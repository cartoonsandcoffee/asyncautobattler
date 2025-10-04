class_name CraftingRecipe
extends Resource

## Defines a crafting recipe for combining items
## Used by ItemsManager to validate and execute crafting

enum RecipeType {
	SAME_ITEM_UPGRADE,  # 2 Common Swords → 1 Golden Sword
	FUSION,             # Different items combine into new item (future)
	CUSTOM              # Special recipes with custom logic (future)
}

@export var recipe_name: String = ""
@export var recipe_type: RecipeType = RecipeType.SAME_ITEM_UPGRADE

# Result
@export var result_item_name: String = ""   # Item name of crafted result (e.g., "Golden Basic Sword")

# Ingredient requirements
@export var ingredient_1_name: String = ""  # Item name (e.g., "Basic Sword")
@export var ingredient_2_name: String = ""  # Item name (must match for SAME_ITEM_UPGRADE)

# Requirements
@export var requires_same_items: bool = true  # For SAME_ITEM_UPGRADE type
@export var requires_same_rarity: bool = true # Both items must be same rarity

func validate_ingredients(item1: Item, item2: Item) -> bool:
	"""Check if these two items can be crafted with this recipe"""
	if not item1 or not item2:
		return false
	
	match recipe_type:
		RecipeType.SAME_ITEM_UPGRADE:
			# Must be same item name and same rarity
			var same_name = (item1.item_name == item2.item_name)
			var matches_recipe = (item1.item_name == ingredient_1_name)
			var same_rarity = (item1.rarity == item2.rarity) if requires_same_rarity else true
			
			return same_name and matches_recipe and same_rarity
		
		RecipeType.FUSION:
			# Check if items match either order
			var match_order_1 = (item1.item_name == ingredient_1_name and 
								item2.item_name == ingredient_2_name)
			var match_order_2 = (item1.item_name == ingredient_2_name and 
								item2.item_name == ingredient_1_name)
			return match_order_1 or match_order_2
		
		RecipeType.CUSTOM:
			# Override this in specific recipe implementations
			# For now, always return false
			return false
	
	return false

func get_result_item() -> Item:
	"""Get the crafted result item from ItemsManager"""
	return ItemsManager.get_item(result_item_name)

func get_recipe_description() -> String:
	"""Get a human-readable description of this recipe"""
	match recipe_type:
		RecipeType.SAME_ITEM_UPGRADE:
			return "2x " + ingredient_1_name + " → " + result_item_name
		RecipeType.FUSION:
			return ingredient_1_name + " + " + ingredient_2_name + " → " + result_item_name
		RecipeType.CUSTOM:
			return recipe_name
	return "Unknown Recipe"