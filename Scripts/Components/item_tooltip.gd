extends Control

@onready var panel: Panel = $Panel
@onready var panel_container: PanelContainer = $Panel/PanelContainer
@onready var vbox: VBoxContainer = $Panel/PanelContainer/MarginContainer/VBoxContainer

@onready var lbl_name: Label = $Panel/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/lblName
@onready var lbl_rarity: Label = $Panel/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/lblRarity
@onready var lbl_desc: RichTextLabel = $Panel/PanelContainer/MarginContainer/VBoxContainer/lblDesc
@onready var stats_grid: GridContainer = $Panel/PanelContainer/MarginContainer/VBoxContainer/statsGrid
@onready var category_grid: GridContainer = $Panel/PanelContainer/MarginContainer/VBoxContainer/categoryGrid

var gamecolors: GameColors

const KEYWORDS = {
	"acid": {
		"color": "#aaff00",
		"description": "Removes armor equal to acid at turn start."
	},
	"poison": {
		"color": "#5b812fff",
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
		"description": "Restore health equalt to regeneration at turn end, then remove 1 stack."
	},
	"stun": {
		"color": "#ffff99",
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
		"color": "#b38b58ff",
		"description": "Your attack is halved as long as you have blind stacks. Remove 1 at turn end."
	},
	"blessing": {
		"color": "#3ca5e2ff",
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
	"hit points": "#44ff44",
	"hitpoints": "#44ff44",
	"health": "#44ff44",
	"gold": "#ffaa00"
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

func set_item(this_item: Item):
	set_references()
	clear_definition_boxes()

	current_item = this_item
	lbl_name.text = this_item.item_name
	set_rarity()
	get_stat_bonuses()

	show_description(this_item)
	show_stats()
	show_categories(this_item.categories)


	#update_panel_size()

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

	if statcount <= 0:
		stats_grid.hide()
	else:
		stats_grid.show()

func show_description(this_item: Item):
	var desc: String = this_item.get_description()

	if desc and desc.length() > 0:
		lbl_desc.text = process_description(desc)
		create_stacked_definitions()
		lbl_desc.show()
	else:
		lbl_desc.hide()

func show_stats():
	stats_grid.columns = stats_to_add.size()

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
	var y_offset = 0
	var extra_spacing: int = 5
	var tooltip_counter: int = 0

	for keyword in found_keywords:
		if keyword not in KEYWORDS:
			continue
		
		var def_box = definition_box_scene.instantiate()
		panel.add_child(def_box)
		def_box.setup(keyword, KEYWORDS[keyword].description, Color(KEYWORDS[keyword].color))
		
		# Position above main panel
		if tooltip_counter > 0:
			y_offset -= (80 + extra_spacing)  # Stack upward 
		
		if current_item.slot_index >= 4:
			def_box.justify_right()
			def_box.position = Vector2((panel_container.position.x - 420 - extra_spacing), (0 + y_offset))
		else:
			def_box.justify_left()
			def_box.position = Vector2((panel_container.position.x + panel_container.size.x + extra_spacing), (0 + y_offset))

		definition_boxes.append(def_box)
		tooltip_counter += 1

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
	else:
		lbl_rarity.modulate =  Color.WHITE
