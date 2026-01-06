extends CanvasLayer

## Global tooltip manager that ensures tooltips are always on top and properly positioned
## Leverages existing item_tooltip.tscn and definition_box.tscn

var current_tooltip: Control = null
var tooltip_offset := Vector2(0, 10)
var padding := 10  # Minimum distance from screen edges

var item_tooltip_scene = preload("res://Scenes/Elements/item_tooltip.tscn")

func _ready():
	# Set high layer to ensure tooltips are always on top
	layer = 100

## Show tooltip for an item at the given global position and size
## Tooltip anchors bottom to top of item and grows upward by default
func show_item_tooltip(item: Item, anchor_global_pos: Vector2, anchor_size: Vector2 = Vector2(100, 100)) -> void:
	hide_tooltip()
	
	if not item:
		return
	
	# Instantiate the existing tooltip scene
	current_tooltip = item_tooltip_scene.instantiate()
	add_child(current_tooltip)
	
	# Setup the tooltip with item data (uses existing item_tooltip.gd logic)
	current_tooltip.set_item(item, false)

	# Wait one frame for tooltip to calculate its size
	await get_tree().process_frame
	
	# Position with bottom of tooltip anchored to top of item
	var positioned = _calculate_anchored_position(current_tooltip, anchor_global_pos, anchor_size)
	current_tooltip.global_position = positioned

	await get_tree().process_frame
	if current_tooltip and current_tooltip.has_method("create_stacked_definitions"):
		current_tooltip.create_stacked_definitions()
		
## Hide current tooltip
func hide_tooltip() -> void:
	if current_tooltip:
		# Clear any definition boxes the tooltip spawned
		if current_tooltip.has_method("clear_definition_boxes"):
			current_tooltip.clear_definition_boxes()
		
		current_tooltip.queue_free()
		current_tooltip = null

## Calculate position anchoring tooltip bottom to item top (grows upward)
## Falls back to anchoring tooltip top to item bottom (grows downward) if insufficient space
func _calculate_anchored_position(tooltip: Control, anchor_pos: Vector2, anchor_size: Vector2) -> Vector2:
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Get tooltip size
	var tooltip_size: Vector2
	if tooltip.has_node("Panel/PanelContainer"):
		var panel = tooltip.get_node("Panel/PanelContainer")
		tooltip_size = panel.size
	else:
		tooltip_size = tooltip.size
	
	var pos = Vector2.ZERO
	
	# VERTICAL: Anchor bottom of tooltip to top of item (grows upward)
	var item_top_y = anchor_pos.y
	var item_bottom_y = anchor_pos.y + anchor_size.y
	
	var pos_above = item_top_y - tooltip_size.y  # Bottom of tooltip at top of item
	var pos_below = item_bottom_y  # Top of tooltip at bottom of item
	
	if pos_above >= padding:
		# Enough space above - anchor bottom to top (grows upward)
		pos.y = item_top_y - tooltip_offset.y #pos_above
	else:
		# Not enough space above - anchor top to bottom (grows downward)
		pos.y = pos_below + tooltip_offset.y
	
	# HORIZONTAL: Try right first, then left if that goes offscreen
	var pos_right = anchor_pos.x + tooltip_offset.x
	var pos_left = anchor_pos.x - (tooltip_size.x - anchor_size.x) - tooltip_offset.x
	
	if pos_right + tooltip_size.x <= viewport_size.x - padding:
		# Right fits
		pos.x = pos_right
	else:
		# Right goes offscreen, use left
		pos.x = pos_left
	
	# Final clamp to ensure tooltip stays on screen
	pos.x = clamp(pos.x, padding, viewport_size.x - tooltip_size.x - padding)
	pos.y = clamp(pos.y, padding, viewport_size.y - padding) # JDM: Might need to add tooltip_size.y to the MIN part of this equation to stop things showing off top of screen

	return pos
