class_name CraftingRecipe
extends Resource

## Defines a crafting recipe for combining items
## Used by ItemsManager to validate and execute crafting


@export var recipe_name: String = ""

# Result
@export var result_item: Item = null  

# Ingredient requirements
@export var ingredient_1: Item = null  
@export var ingredient_2: Item = null 

@export var is_unlocked: bool = true

func validate_ingredients(item1: Item, item2: Item) -> bool:
	"""Check if these two items can be crafted with this recipe"""
	if not item1 or not item2:
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
