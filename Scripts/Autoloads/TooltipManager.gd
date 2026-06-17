extends CanvasLayer

## Global tooltip manager that ensures tooltips are always on top and properly positioned
## Leverages existing item_tooltip.tscn and definition_box.tscn

var current_tooltip: Control = null
var tooltip_offset := Vector2(0, 10)
var padding := 10  # Minimum distance from screen edges
var _placement_side: String = "above"
var _tooltip_gen: int = 0

var item_tooltip_scene = preload("res://Scenes/Card/item_card_wide.tscn")
var _pooled_tooltip: Control = null

func _ready():
	# Set high layer to ensure tooltips are always on top
	layer = 100
	_pooled_tooltip = item_tooltip_scene.instantiate()
	add_child(_pooled_tooltip)
	_pooled_tooltip.hide()


## Show tooltip for an item at the given global position and size
## Tooltip anchors bottom to top of item and grows upward by default
func show_item_tooltip(item: Item, anchor_global_pos: Vector2, anchor_size: Vector2 = Vector2(100, 100), is_from_compendium: bool = false, entity = null) -> void:
	hide_tooltip()

	if not item:
		return

	_tooltip_gen += 1
	var my_gen := _tooltip_gen

	# Reuse pooled instance
	current_tooltip = _pooled_tooltip
	current_tooltip.is_from_compendium = is_from_compendium
	current_tooltip._details_visible = false
	current_tooltip.show()

	# Setup the tooltip with item data (uses existing item_tooltip.gd logic)
	current_tooltip.set_item(item, false, entity)

	# Show crafting recipe ingredients for CRAFTED rarity items
	if item.rarity == Enums.Rarity.CRAFTED:
		var recipe: CraftingRecipe = ItemsManager.get_recipe_for_item(item)
		if recipe:
			var ingredients: Array[Item] = []
			if recipe.ingredient_1:
				ingredients.append(recipe.ingredient_1)
			if recipe.ingredient_2:
				ingredients.append(recipe.ingredient_2)
			if ingredients.size() > 0:
				current_tooltip.set_bonus_ingredients(ingredients)
	
	# Set bonus membership display
	if item.item_type != Item.ItemType.SET_BONUS:
		var set_bonus: SetBonus = SetBonusManager.get_set_bonus_for_item(item)
		if set_bonus:
			current_tooltip.set_pending_set_bonus(set_bonus)
			
	current_tooltip.show_card()

	# Wait one frame for tooltip to calculate its size
	await get_tree().process_frame
	
	if not is_instance_valid(current_tooltip):
		return

	## JDM - TEST TO SEE IF MOBILE FIXES CARD DISPLAY ----------
	# Poll up to 5 frames for tooltip size to resolve — single frame is unreliable on mobile
	var tooltip_size := Vector2.ZERO
	for _i in range(5):
		await get_tree().process_frame
		if _tooltip_gen != my_gen or not is_instance_valid(current_tooltip):
			return
		tooltip_size = _get_tooltip_size(current_tooltip)
		if tooltip_size != Vector2.ZERO:
			break

	if _tooltip_gen != my_gen or not is_instance_valid(current_tooltip):
		return

	## --------------------------------------------

	# Position with bottom of tooltip anchored to top of item
	#var positioned = _calculate_anchored_position(current_tooltip, anchor_global_pos, anchor_size)
	var positioned := _calculate_anchored_position(anchor_global_pos, anchor_size, tooltip_size)
	current_tooltip.global_position = positioned
	current_tooltip.placement_side = _placement_side

	await get_tree().process_frame

	## JDM - test
	if _tooltip_gen != my_gen or not is_instance_valid(current_tooltip):
		return
	
	if is_instance_valid(current_tooltip) and current_tooltip.is_from_compendium:
		if current_tooltip.has_method("create_stacked_definitions"):
			current_tooltip.create_stacked_definitions()

func show_setbonus_tooltip(item: Item, anchor_global_pos: Vector2, anchor_size: Vector2 = Vector2(100, 100), is_from_compendium: bool = false, recipe = null) -> void:
	hide_tooltip()

	if not item:
		return

	_tooltip_gen += 1
	var my_gen := _tooltip_gen

	current_tooltip = _pooled_tooltip
	current_tooltip.is_from_compendium = is_from_compendium
	current_tooltip._details_visible = false
	current_tooltip.show()
	current_tooltip.set_item(item, false, null)

	if recipe:
		current_tooltip.set_bonus_ingredients(recipe.required_items)

	current_tooltip.show_card()

	var tooltip_size := Vector2.ZERO
	for _i in range(5):
		await get_tree().process_frame
		if _tooltip_gen != my_gen or not is_instance_valid(current_tooltip):
			return
		tooltip_size = _get_tooltip_size(current_tooltip)
		if tooltip_size != Vector2.ZERO:
			break

	if _tooltip_gen != my_gen or not is_instance_valid(current_tooltip):
		return

	var positioned := _calculate_anchored_position(anchor_global_pos, anchor_size, tooltip_size)
	current_tooltip.global_position = positioned
	current_tooltip.placement_side = _placement_side

	await get_tree().process_frame
	if _tooltip_gen != my_gen or not is_instance_valid(current_tooltip):
		return
	if is_instance_valid(current_tooltip) and current_tooltip.is_from_compendium:
		if current_tooltip.has_method("create_stacked_definitions"):
			current_tooltip.create_stacked_definitions()

## Hide current tooltip
func hide_tooltip() -> void:
	if current_tooltip:
		# Clear any definition boxes the tooltip spawned
		if current_tooltip.has_method("clear_definition_boxes"):
			current_tooltip.clear_definition_boxes()
		
		current_tooltip.hide()
		current_tooltip = null

func expand_current_tooltip_definitions() -> void:
	if not is_instance_valid(current_tooltip):
		return
	if current_tooltip.is_from_compendium:
		return
	if current_tooltip._details_visible:
		return
	if current_tooltip.has_method("create_stacked_definitions"):
		current_tooltip._details_visible = true
		current_tooltip.create_stacked_definitions()

func _get_tooltip_size(tooltip: Control) -> Vector2:
	if tooltip.has_node("Panel/Control/PanelContainer"):
		var sz : Vector2 = tooltip.get_node("Panel/Control/PanelContainer").size
		if sz != Vector2.ZERO:
			return sz
	if tooltip.size != Vector2.ZERO:
		return tooltip.size
	return tooltip.get_combined_minimum_size()

## Calculate position anchoring tooltip bottom to item top (grows upward)
## Falls back to anchoring tooltip top to item bottom (grows downward) if insufficient space
func _calculate_anchored_position(anchor_pos: Vector2, anchor_size: Vector2, tooltip_size: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size

	var item_left     := anchor_pos.x
	var item_right    := anchor_pos.x + anchor_size.x
	var item_top      := anchor_pos.y
	var item_bottom   := anchor_pos.y + anchor_size.y
	var item_center_x := anchor_pos.x + anchor_size.x / 2.0
	var item_center_y := anchor_pos.y + anchor_size.y / 2.0

	var fits_above := (item_top    - padding - tooltip_size.y) >= padding
	var fits_below := (item_bottom + padding + tooltip_size.y) <= (viewport_size.y - padding)
	var fits_left  := (item_left   - padding - tooltip_size.x) >= padding
	var fits_right := (item_right  + padding + tooltip_size.x) <= (viewport_size.x - padding)

	var pos := Vector2.ZERO

	if fits_above:
		_placement_side = "above"
		pos.y = item_top - padding - tooltip_size.y
		pos.x = clamp(item_center_x - tooltip_size.x / 2.0, padding, viewport_size.x - tooltip_size.x - padding)
	elif fits_below:
		_placement_side = "below"
		pos.y = item_bottom + padding
		pos.x = clamp(item_center_x - tooltip_size.x / 2.0, padding, viewport_size.x - tooltip_size.x - padding)
	elif fits_left or fits_right:
		var space_right := viewport_size.x - item_right
		var space_left  := item_left
		if fits_right and (not fits_left or space_right >= space_left):
			_placement_side = "right"
			pos.x = item_right + padding
		else:
			_placement_side = "left"
			pos.x = item_left - padding - tooltip_size.x
		pos.y = clamp(item_center_y - tooltip_size.y / 2.0, padding, viewport_size.y - tooltip_size.y - padding)
	else:
		_placement_side = "above"
		pos.y = item_top - padding - tooltip_size.y
		pos.x = clamp(item_center_x - tooltip_size.x / 2.0, padding, viewport_size.x - tooltip_size.x - padding)

	# Safety clamp — maxf guards against inverted range when tooltip exceeds viewport
	pos.x = clamp(pos.x, padding, maxf(viewport_size.x - tooltip_size.x - padding, padding))
	pos.y = clamp(pos.y, padding, maxf(viewport_size.y - tooltip_size.y - padding, padding))

	return pos
