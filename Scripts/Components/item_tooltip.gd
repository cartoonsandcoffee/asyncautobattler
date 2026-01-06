extends Control

@onready var panel: Panel 
@onready var panel_container: PanelContainer 
@onready var vbox: VBoxContainer 

@onready var lbl_name: Label 
@onready var lbl_rarity: Label
@onready var lbl_desc: RichTextLabel 
@onready var stats_grid: GridContainer 
@onready var category_grid: GridContainer

var gamecolors: GameColors

const KEYWORDS = {
	"acid": {
		"color": "#aaff00",
		"description": "Removes armor equal to acid at turn start."
	},
	"poison": {
		"color": "#ff66ff",
		"description": "If you have no shield, take damage equal to poison at turn start. Remove 1 stack at turn start."
	},
	"burn": {
		"color": "#ff6600",
		"description": "At turn end, remove 1 burn stack and take 3 damage."
	},
	"thorns": {
		"color": "#996633",
		"description": "Deal damage equal to your thorn stacks when hit, then remove those thorns. "
	},
	"regeneration": {
		"color": "#00ff88",
		"description": "Restore health equal to regeneration at turn end, then remove 1 stack."
	},
	"stun": {
		"color": "#bdb280ff",
		"description": "When stunned you skip your next strike. Remove 1 stun for each strike you skip."
	},	
	"exposed": {
		"color": "#96b6c9ff",
		"description": "Triggered when shield reaches 0 for the first time in combat."
	},
	"wounded": {
		"color": "#af4545ff",
		"description": "Triggered when HP reaches 50% or lower for the first time each combat."
	},
	"blind": {
		"color": "#fff5cf",
		"description": "Your attack is halved as long as you have blind stacks. Remove 1 at turn end."
	},
	"blessing": {
		"color": "#99dfffff",
		"description": "When removed, gain 1 attack per stack and 3 health."
	}		
}

# Trigger keywords (for special formatting)
const TRIGGER_KEYWORDS = {
	"on hit": "#ffdddd",
	"on battle start": "#ddffdd",
	"battle start": "#ddffdd",
	"turn start": "#ddddff",
	"countdown": "#ffddff",
	"shield": "#6699ff",
	"armor": "#6699ff",	
	"damage": "#ff4444",
	"attack": "#ff4444",	
	"agility": "#ffdd44",
	"speed": "#ffdd44",
	"strikes": "#d0db9eff",	
	"hit points": "#44ff44",
	"hitpoints": "#44ff44",
	"health": "#44ff44",
	"gold": "#ffaa00",
	"burn damage": "#ff6600"
}

var current_item: Item = null

var stat_item = preload("res://Scenes/Elements/stat_item.tscn")
var category_item = preload("res://Scenes/Elements/category_label.tscn")
var definition_box_scene = preload("res://Scenes/Elements/definition_box.tscn")

var stats_to_add: Dictionary = {}
var definition_boxes: Array[Control] = []
var found_keywords = []


func set_references():
	panel = $Panel
	panel_container = $Panel/PanelContainer
	lbl_name = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/lblName
	lbl_rarity = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/lblRarity	
	lbl_desc = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/lblDesc
	stats_grid = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/statsGrid
	category_grid = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/categoryGrid
	vbox = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer
	gamecolors = GameColors.new()

func set_item(this_item: Item, create_definitions: bool = true):
	set_references()
	clear_definition_boxes()

	current_item = this_item
	lbl_name.text = this_item.item_name
	set_rarity()
	get_stat_bonuses()

	show_description(this_item, create_definitions)
	show_stats()
	show_categories(this_item.categories)

	if this_item.item_type == Item.ItemType.SET_BONUS:
		set_bonus()
	#update_panel_size()
	
func set_bonus():
	lbl_rarity.visible = false
	category_grid.visible = false

func set_tooltip_position(_pos: Vector2):
	global_position = _pos

func get_stat_bonuses():
	stats_to_add.clear()
	var statcount: int = 0

	if current_item.damage_bonus != 0:
		stats_to_add[statcount] = {"name": "damage", "value": str(current_item.damage_bonus)}
		statcount += 1
	if current_item.shield_bonus != 0:
		stats_to_add[statcount] = {"name": "shield", "value": str(current_item.shield_bonus)}
		statcount += 1	
	if current_item.agility_bonus != 0:
		stats_to_add[statcount] = {"name": "agility", "value": str(current_item.agility_bonus)}
		statcount += 1	
	if current_item.hit_points_bonus != 0:
		stats_to_add[statcount] = {"name": "hitpoints", "value": str(current_item.hit_points_bonus)}
		statcount += 1	
	if current_item.strikes_bonus != 0:
		stats_to_add[statcount] = {"name": "strikes", "value": str(current_item.strikes_bonus)}
		statcount += 1	
	if current_item.burn_damage_bonus != 0:
		stats_to_add[statcount] = {"name": "burn_damage", "value": str(current_item.burn_damage_bonus)}
		statcount += 1	

	if statcount <= 0:
		stats_grid.hide()
	else:
		stats_grid.show()

func show_description(this_item: Item, create_definitions: bool = true):
	var desc: String = this_item.get_description()

	if desc and desc.length() > 0:
		lbl_desc.text = process_description(desc)
		if create_definitions:
			create_stacked_definitions()
		lbl_desc.show()
	else:
		lbl_desc.hide()

func show_stats():
	if stats_to_add.size() == 0:
		stats_grid.hide()
		return

	stats_grid.columns = stats_to_add.size()
	stats_grid.show()

	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()

	for key in stats_to_add:
		var stat = stat_item.instantiate()
		stat.update_stat(stats_to_add[key].name, stats_to_add[key].value)
		stat.custom_minimum_size = Vector2(80, 60)
		stats_grid.add_child(stat)

func show_categories(categories: Array[String]):
	for child in category_grid.get_children():
		category_grid.remove_child(child)
		child.queue_free()
	if categories.size() > 0:
		category_grid.columns = categories.size() 
		for category in categories:
			var cat_container = category_item.instantiate()
			cat_container.get_node("PanelContainer/MarginContainer/lblCategory").text = category
			cat_container.custom_minimum_size = Vector2(140,40)
			category_grid.add_child(cat_container)
		category_grid.show()
	else:
		category_grid.hide()

func process_description(text: String) -> String:
	var processed_text = text
	var keywords_in_text = []

	for trigger in TRIGGER_KEYWORDS:
		var color = TRIGGER_KEYWORDS[trigger]
		# Case-insensitive replacement
		var regex = RegEx.new()
		regex.compile("(?i)\\b" + trigger + "\\b")
		var matches = regex.search_all(processed_text)
		
		# Process matches in reverse to maintain string positions
		for i in range(matches.size() - 1, -1, -1):
			var match = matches[i]
			var original = match.get_string()
			var replacement = "[color=%s][b]%s[/b][/color]" % [color, original]
			processed_text = processed_text.substr(0, match.get_start()) + replacement + processed_text.substr(match.get_end())
 
	# find the keywords so we can define them later
	for keyword in KEYWORDS:
		var regex = RegEx.new()
		regex.compile("(?i)\\b" + keyword + "\\b")
		if regex.search(text):
			keywords_in_text.append(keyword)
	
	# Sort by order of appearance (optional)
	keywords_in_text.sort_custom(func(a, b): 
		return text.find(a) < text.find(b)
	)

	# Then process status/stat keywords with tooltips
	for keyword in KEYWORDS:
		var data = KEYWORDS[keyword]
		var color = data.color
		
		# Case-insensitive search
		var regex = RegEx.new()
		regex.compile("(?i)\\b" + keyword + "\\b")
		var matches = regex.search_all(processed_text)
		
		# Process matches in reverse
		for i in range(matches.size() - 1, -1, -1):
			var match = matches[i]
			var original = match.get_string()
			# Add URL meta tag for tooltip functionality
			var replacement = "[color=%s][b][url=%s]%s[/url][/b][/color]" % [color, keyword.to_lower(), original]
			processed_text = processed_text.substr(0, match.get_start()) + replacement + processed_text.substr(match.get_end())
	
	found_keywords = keywords_in_text
	return processed_text

func create_stacked_definitions():
	var extra_spacing: int = 5
	var def_box_width: float = 420.0
	
	# Start at bottom of tooltip (y=0 since Panel is bottom-anchored)
	# First definition box bottom should be flush with tooltip bottom
	var y_offset = 20

	for i in range(found_keywords.size()):
		var keyword = found_keywords[i]
		if keyword not in KEYWORDS:
			continue
		
		var def_box = definition_box_scene.instantiate()
		panel.add_child(def_box)
		def_box.setup(keyword, KEYWORDS[keyword].description, Color(KEYWORDS[keyword].color))
		
		# Wait one frame for def_box size to be calculated
		await get_tree().process_frame
		
		# Get actual viewport and tooltip positions
		var viewport_size = get_viewport().get_visible_rect().size
		var tooltip_global_x = global_position.x
		var panel_right_edge = tooltip_global_x + panel_container.size.x
		var panel_left_edge = tooltip_global_x
		
		# Calculate positions for both sides
		var pos_right_x = panel_container.size.x + extra_spacing
		var pos_left_x = -def_box_width - extra_spacing
		
		# Check which side has room in global coordinates
		var global_right_edge = panel_right_edge + def_box_width + extra_spacing
		var global_left_edge = panel_left_edge - def_box_width - extra_spacing
		
		# Decide positioning
		var use_right_side = true
		if global_right_edge > viewport_size.x - 10:  # Would go offscreen right
			if global_left_edge >= 10:  # Left side has room
				use_right_side = false
		
		# Set position and justification
		if use_right_side:
			def_box.justify_left()
			def_box.position = Vector2(pos_right_x, y_offset)
		else:
			def_box.justify_right()
			def_box.position = Vector2(pos_left_x, y_offset)
		
		definition_boxes.append(def_box)
		def_box.show_def()

		# Stack upward for next box (negative y since Panel is bottom-anchored)
		if i < found_keywords.size() - 1:  # If not the last one
			y_offset -= (85 + extra_spacing)

func clear_definition_boxes():
	for box in definition_boxes:
		box.queue_free()
	definition_boxes.clear()
	found_keywords.clear()

func set_rarity_color() -> Color:
	if current_item.rarity == Enums.Rarity.COMMON:
		return gamecolors.rarity.common
	elif current_item.rarity == Enums.Rarity.UNCOMMON:
		return gamecolors.rarity.uncommon
	elif current_item.rarity == Enums.Rarity.RARE:
		return gamecolors.rarity.rare
	elif current_item.rarity == Enums.Rarity.LEGENDARY:
		return gamecolors.rarity.legendary
	elif current_item.rarity == Enums.Rarity.GOLDEN:
		return gamecolors.rarity.golden
	elif current_item.rarity == Enums.Rarity.DIAMOND:
		return gamecolors.rarity.diamond
	else:
		return Color.WHITE

func set_rarity():
	if current_item.rarity == Enums.Rarity.COMMON:
		lbl_rarity.modulate = gamecolors.rarity.common
		lbl_rarity.text = " - Common -"
	elif current_item.rarity == Enums.Rarity.UNCOMMON:
		lbl_rarity.modulate =  gamecolors.rarity.uncommon
		lbl_rarity.text = " - Uncommon -"
	elif current_item.rarity == Enums.Rarity.RARE:
		lbl_rarity.modulate =  gamecolors.rarity.rare
		lbl_rarity.text = " - Rare -"
	elif current_item.rarity == Enums.Rarity.LEGENDARY:
		lbl_rarity.modulate =  gamecolors.rarity.legendary	
		lbl_rarity.text = " - Legendary -"
	elif current_item.rarity == Enums.Rarity.GOLDEN:
		lbl_rarity.modulate =  gamecolors.rarity.golden	
		lbl_rarity.text = " - Golden -"
	elif current_item.rarity == Enums.Rarity.DIAMOND:
		lbl_rarity.modulate =  gamecolors.rarity.diamond	
		lbl_rarity.text = " - Diamond -"
	else:
		lbl_rarity.modulate =  Color.WHITE
