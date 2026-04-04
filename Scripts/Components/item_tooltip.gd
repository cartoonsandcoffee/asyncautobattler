extends Control

@onready var panel: Panel 
@onready var panel_container: PanelContainer 
@onready var vbox: VBoxContainer 

@onready var lbl_name: Label 
@onready var lbl_desc: RichTextLabel 
@onready var stats_grid: GridContainer 
@onready var category_grid: GridContainer
@onready var txt_upgrades: RichTextLabel
@onready var set_ingredients: GridContainer

@onready var lbl_rarity: Label
@onready var pic_rarity: TextureRect
@onready var box_rarity: HBoxContainer

@onready var box_bundle: HBoxContainer
@onready var panel_bundle: PanelContainer
@onready var lbl_bundle: Label

var gamecolors: GameColors
var is_from_compendium: bool = false

var KEYWORDS: Dictionary = {}

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
	"hitpoint": "#44ff44",	
	"health": "#44ff44",
	"gold": "#ffaa00",
	"burn damage": "#ff6600"
}

var current_item: Item = null
var current_entity = null  # player or enemy (for upgrade displaying on weapons)

var stat_item = preload("res://Scenes/Elements/stat_item.tscn")
var category_item = preload("res://Scenes/Elements/category_label.tscn")
var definition_box_scene = preload("res://Scenes/Elements/definition_box.tscn")
var set_ingredient_item = preload("res://Scenes/Elements/set_bonus_display.tscn")

var stats_to_add: Dictionary = {}
var definition_boxes: Array[Control] = []
var found_keywords = []

func _init_keywords():
	KEYWORDS = {
		"acid": {
			"color": GameColors.stats.acid,
			"description": "Removes shield equal to acid at turn start.",
			"icon": CombatLog.ICON_ACID
		},
		"poison": {
			"color": GameColors.stats.poison,
			"description": "If you have no shield, take damage equal to poison at turn start. Remove 1 stack at turn start.",
			"icon": CombatLog.ICON_POISON
		},
		"burn": {
			"color": GameColors.stats.burn,
			"description": "At turn end, take damage equal to enemy's burn damage stat and remove 1 burn stack.",
			"icon": CombatLog.ICON_BURN
		},
		"thorns": {
			"color": GameColors.stats.thorns,
			"description": "Deal damage equal to your thorn stacks when hit, then remove those thorns at turn end. ",
			"icon": CombatLog.ICON_THORNS
		},
		"regeneration": {
			"color": GameColors.stats.regeneration,
			"description": "Restore health equal to regeneration at turn end, then remove 1 stack.",
			"icon": CombatLog.ICON_REGEN
		},
		"stun": {
			"color": GameColors.stats.stun,
			"description": "When stunned you cannot strike with your weapon. Remove 1 stun each time a strike is skipped.",
			"icon": CombatLog.ICON_STUN
		},	
		"stunned": {
			"color": GameColors.stats.stun,
			"description": "When stunned you cannot strike with your weapon. Remove 1 stun each time a strike is skipped.",
			"icon": CombatLog.ICON_STUN
		},		
		"exposed": {
			"color": GameColors.stats.exposed,
			"description": "Triggered when shield reaches 0 for the first time in battle.",
			"icon": CombatLog.ICON_EXPOSED
		},
		"wounded": {
			"color": GameColors.stats.wounded,
			"description": "Triggered when HP reaches 50% or lower for the first time each battle.",
			"icon": CombatLog.ICON_WOUNDED
		},
		"blind": {
			"color": GameColors.stats.blind,
			"description": "Your attack is halved as long as you have blind stacks. Remove 1 stack at turn end.",
			"icon": CombatLog.ICON_BLIND
		},
		"blessing": {
			"color": GameColors.stats.blessing,
			"description": "Gain 1 attack and heal 3 hitpoints per stack removed. Only removable via items.",
			"icon": CombatLog.ICON_BLESSING
		},
		"strikes": {
			"color": GameColors.stats.strikes,
			"description": "How many times you hit with your weapon in a single turn.",
			"icon": CombatLog.ICON_STRIKES
		},
		"strike": {
			"color": GameColors.stats.strikes,
			"description": "How many times you hit with your weapon in a single turn.",
			"icon": CombatLog.ICON_STRIKES
		},
		"singularity": {
			"color": GameColors.stats.singularity,
			"description": "While you have a 'Singularity' item, no others will appear in the shop.",
			"icon": null
		},
		"overheal": {
			"color": GameColors.stats.hit_points,
			"description": "Triggers whenever you would gain hitpoints but are already full.",
			"icon": null
		}	
	}

func set_references():
	panel = $Panel
	panel_container = $Panel/PanelContainer
	lbl_name = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/lblName
	lbl_rarity = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/rarityBox/lblRarity
	pic_rarity = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/rarityBox/picRarity
	box_rarity = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/rarityBox
	lbl_desc = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/lblDesc
	stats_grid = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/statsGrid
	category_grid = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/categoryGrid
	vbox = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer
	txt_upgrades = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/txtUpgrades
	lbl_bundle = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/boxBundle/panelBundle/lblBundle
	panel_bundle = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/boxBundle/panelBundle
	box_bundle = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/boxBundle
	set_ingredients = $Panel/PanelContainer/MarginContainer2/PanelContainer/MarginContainer/VBoxContainer/setIngredients
	gamecolors = GameColors.new()
	if KEYWORDS.is_empty():
		_init_keywords()

func set_item(this_item: Item, create_definitions: bool = true, entity = null):
	set_references()
	clear_definition_boxes()

	current_item = this_item
	current_entity = entity

	lbl_name.text = this_item.item_name

	if entity:
		if entity.current_weapon_rule_upgrade && this_item.item_type == Item.ItemType.WEAPON:
			lbl_name.text = entity.current_weapon_rule_upgrade.item_name + " " + this_item.item_name

	set_rarity()
	get_stat_bonuses()

	set_upgrades()

	show_description(this_item, create_definitions, entity)
	show_stats()
	show_categories(this_item.categories)
	set_bundle()
	
	if this_item.item_type == Item.ItemType.SET_BONUS:
		set_bonus()
	#update_panel_size()
	
func set_bonus():
	lbl_rarity.text = " Set Bonus  - "
	box_rarity.modulate = Color.WHITE
	pic_rarity.visible = false
	category_grid.visible = false

func set_tooltip_position(_pos: Vector2):
	global_position = _pos

func set_bonus_ingredients(_items: Array[Item]):
	for child in set_ingredients.get_children():
		child.queue_free()

	if _items.is_empty():
		return

	for item in _items:
		var item_slot = set_ingredient_item.instantiate()
		item_slot.set_bonus(item)
		item_slot.turn_off_shader()
		#item_slot.custom_minimum_size = Vector2(90, 90) 
		item_slot.scale = Vector2(0.5, 0.5)

		set_ingredients.add_child(item_slot)

	set_ingredients.visible = true

func set_bundle():
	if is_from_compendium:
		box_bundle.visible = true
		panel_bundle.modulate = gamecolors.get_bundle_color(current_item.item_bundle)
		lbl_bundle.text = Enums.get_bundle_string(current_item.item_bundle)
	else:
		box_bundle.visible = false

func set_upgrades():
	var str_upgrades: String = ""
	
	var entity_to_check = current_entity if current_entity != null else Player

	if !is_from_compendium:
		if entity_to_check.inventory:
			if current_item.item_type == Item.ItemType.WEAPON:
				if current_item.item_id != entity_to_check.inventory.weapon_slot.item_id:
					return

				if entity_to_check.current_weapon_stat_upgrades["damage"] > 0 :
					str_upgrades += "[color=#ff4444][b] blood[/b][/color]"
				if entity_to_check.current_weapon_stat_upgrades["shield"] > 0 :
					if str_upgrades != "":
						str_upgrades += ","
					str_upgrades += "[color=#6699ff][b] spit[/b][/color] "
				if entity_to_check.current_weapon_stat_upgrades["agility"] > 0 :
					if str_upgrades != "":
						if str_upgrades.contains(","):
							str_upgrades += ", and"
						else:
							str_upgrades += " and"
					str_upgrades += "[color=#ffdd44][b] sweat[/b][/color]"
			
	if str_upgrades != "":
		txt_upgrades.visible = true
		txt_upgrades.text = "It's covered in" + str_upgrades + "."

func get_stat_bonuses():
	stats_to_add.clear()
	var statcount: int = 0

	# Determine which entity to check for upgrades
	var entity_to_check = current_entity if current_entity != null else Player

	if !is_from_compendium:
		if entity_to_check.inventory:
			if current_item.item_type == Item.ItemType.WEAPON && current_item.item_id == entity_to_check.inventory.weapon_slot.item_id:
				if current_item.damage_bonus != 0 || entity_to_check.current_weapon_stat_upgrades["damage"] != 0 :
					stats_to_add[statcount] = {"name": "damage", "value": str(current_item.damage_bonus + entity_to_check.current_weapon_stat_upgrades["damage"])}
					statcount += 1
				if current_item.shield_bonus != 0 || entity_to_check.current_weapon_stat_upgrades["shield"] != 0 :
					stats_to_add[statcount] = {"name": "shield", "value": str(current_item.shield_bonus + entity_to_check.current_weapon_stat_upgrades["shield"])}
					statcount += 1
				if current_item.agility_bonus != 0 || entity_to_check.current_weapon_stat_upgrades["agility"] != 0 :
					stats_to_add[statcount] = {"name": "agility", "value": str(current_item.agility_bonus + entity_to_check.current_weapon_stat_upgrades["agility"])}
					statcount += 1
			else:
				if current_item.damage_bonus != 0:
					stats_to_add[statcount] = {"name": "damage", "value": str(current_item.damage_bonus)}
					statcount += 1
				if current_item.shield_bonus != 0:
					stats_to_add[statcount] = {"name": "shield", "value": str(current_item.shield_bonus)}
					statcount += 1	
				if current_item.agility_bonus != 0:
					stats_to_add[statcount] = {"name": "agility", "value": str(current_item.agility_bonus)}
					statcount += 1	
	else:
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

func show_description(this_item: Item, create_definitions: bool = true, entity = null):
	var desc: String = this_item.get_description()

	if entity:
		if entity.current_weapon_rule_upgrade && this_item.item_type == Item.ItemType.WEAPON:
			if desc.length() > 0:
				desc += "\n\n"
			desc += entity.current_weapon_rule_upgrade.get_description()

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
			if category == "Unique":
				cat_container.get_node("PanelContainer/MarginContainer/Button").tooltip_text = "Can only equip one of this item."
			if category == "Singularity":
				cat_container.get_node("PanelContainer/MarginContainer/Button").tooltip_text = "Only one Singularity item equippable at a time."
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
			#var replacement = "[color=%s][b][url=%s]%s[/url][/b][/color]" % [color, keyword.to_lower(), original]
			var replacement = "[color=#%s][b][url=%s]%s[/url][/b][/color]" % [data.color.to_html(false), keyword.to_lower(), original]
			processed_text = processed_text.substr(0, match.get_start()) + replacement + processed_text.substr(match.get_end())
	
	found_keywords = keywords_in_text
	return processed_text

func create_stacked_definitions():
	var extra_spacing: int = 5
	var def_box_width: float = 460.0
	
	# Start at bottom of tooltip (y=0 since Panel is bottom-anchored)
	# First definition box bottom should be flush with tooltip bottom
	var y_offset = 20

	for i in range(found_keywords.size()):
		var keyword = found_keywords[i]
		if keyword not in KEYWORDS:
			continue
		
		var def_box = definition_box_scene.instantiate()
		panel.add_child(def_box)
		def_box.setup(keyword, KEYWORDS[keyword].description, KEYWORDS[keyword].color)
		
		var icon_path = KEYWORDS[keyword].get("icon", null)
		if icon_path:
			def_box.show_pic(load(icon_path), Color(KEYWORDS[keyword].color))

		# Wait one frame for def_box size to be calculated
		await get_tree().process_frame
		
		# Get actual viewport and tooltip positions
		var viewport_size = get_viewport().get_visible_rect().size
		var tooltip_global_x = global_position.x
		var tooltip_width = panel_container.size.x
		
		# Calculate how much space is available on each side
		var space_on_left = tooltip_global_x  # Distance from left edge of screen to left edge of tooltip
		var space_on_right = viewport_size.x - (tooltip_global_x + tooltip_width)  # Distance from right edge of tooltip to right edge of screen
		
		# Calculate positions for both sides (relative to panel)
		var pos_right_x = tooltip_width + extra_spacing
		var pos_left_x = -def_box_width - extra_spacing
		
		# Choose side with MORE available space
		var use_right_side = (space_on_right >= space_on_left)
		
		# Additional check: make sure chosen side actually fits
		if use_right_side:
			# Check if definition box would go offscreen on the right
			if space_on_right < (def_box_width + extra_spacing + 10):
				# Not enough room on right, try left
				if space_on_left >= (def_box_width + extra_spacing + 10):
					use_right_side = false
		else:
			# Check if definition box would go offscreen on the left
			if space_on_left < (def_box_width + extra_spacing + 10):
				# Not enough room on left, try right
				if space_on_right >= (def_box_width + extra_spacing + 10):
					use_right_side = true
		
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
	var rarity_common: Texture2D = load("res://Resources/Rarity/common.tres")
	var rarity_uncommon: Texture2D = load("res://Resources/Rarity/uncommon.tres")
	var rarity_rare: Texture2D = load("res://Resources/Rarity/rare.tres")
	var rarity_legendary: Texture2D = load("res://Resources/Rarity/legendary.tres")
	var rarity_mystic: Texture2D = load("res://Resources/Rarity/mystic.tres")
	var rarity_golden: Texture2D = load("res://Resources/Rarity/golden.tres")
	var rarity_diamond: Texture2D = load("res://Resources/Rarity/diamond.tres")
	var rarity_crafted: Texture2D = load("res://Resources/Rarity/crafted.tres")

	if current_item.rarity == Enums.Rarity.COMMON:
		box_rarity.modulate = gamecolors.rarity.common
		pic_rarity.texture = rarity_common
		lbl_rarity.text = " Common  -"
	elif current_item.rarity == Enums.Rarity.UNCOMMON:
		box_rarity.modulate =  gamecolors.rarity.uncommon
		pic_rarity.texture = rarity_uncommon
		lbl_rarity.text = " Uncommon  -"
	elif current_item.rarity == Enums.Rarity.RARE:
		box_rarity.modulate =  gamecolors.rarity.rare
		pic_rarity.texture = rarity_rare
		lbl_rarity.text = " Rare  -"
	elif current_item.rarity == Enums.Rarity.LEGENDARY:
		box_rarity.modulate =  gamecolors.rarity.legendary
		pic_rarity.texture = rarity_legendary
		lbl_rarity.text = " Legendary  -"
	elif current_item.rarity == Enums.Rarity.GOLDEN:
		box_rarity.modulate =  gamecolors.rarity.golden
		pic_rarity.texture = rarity_golden
		lbl_rarity.text = " Golden  -"
	elif current_item.rarity == Enums.Rarity.DIAMOND:
		box_rarity.modulate =  gamecolors.rarity.diamond
		pic_rarity.texture = rarity_diamond
		lbl_rarity.text = " Diamond  -"
	elif current_item.rarity == Enums.Rarity.CRAFTED:
		box_rarity.modulate =  gamecolors.rarity.crafted
		pic_rarity.texture = rarity_crafted
		lbl_rarity.text = " Crafted  -"
	else:
		box_rarity.modulate =  Color.GRAY
		lbl_rarity.text = " Unknown Rarity  -"
		pic_rarity.visible = false
