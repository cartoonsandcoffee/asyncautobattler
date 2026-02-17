class_name CraftingRecipe
extends Resource

## Defines a crafting recipe for combining items
## Used by ItemsManager to validate and execute crafting


@export var recipe_name: String = ""
@export var recipe_id: String = ""

# Result
@export var result_item: Item:
	get:
		if result_item == null:
			push_warning("CraftingRecipe has no result_item")
		return result_item
	set(value):
		result_item = value

# Ingredient requirements
@export var ingredient_1: Item:
	get:
		if ingredient_1 == null:
			push_warning("CraftingRecipe has no ingredient_1")
		return ingredient_1
	set(value):
		ingredient_1 = value

@export var ingredient_2: Item:
	get:
		if ingredient_2 == null:
			push_warning("CraftingRecipe has no ingredient_2")
		return ingredient_2
	set(value):
		ingredient_2 = value

@export var is_unlocked: bool = true

func validate_ingredients(item1: Item, item2: Item) -> bool:
	"""Check if these two items can be crafted with this recipe"""
	if not item1 or not item2:
		return false
	
	if not ingredient_1 or not ingredient_2:
		return false
		
	var match_order_1 = (item1.item_name == ingredient_1.item_name and 
						item2.item_name == ingredient_2.item_name)
	var match_order_2 = (item1.item_name == ingredient_2.item_name and 
						item2.item_name == ingredient_1.item_name)
	return match_order_1 or match_order_2


func get_result_item() -> Item:
	return result_item

func get_recipe_description() -> String:
	return ingredient_1.item_name + " + " + ingredient_2.item_name + " = " + result_item.item_name
