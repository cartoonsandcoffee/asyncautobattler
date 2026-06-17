extends Control

@onready var panel_container: PanelContainer 
@onready var panel: Panel

@onready var lbl_name: Label 
@onready var lbl_desc: RichTextLabel 
@onready var stats_grid: HBoxContainer 
@onready var category_grid: GridContainer
@onready var txt_upgrades: RichTextLabel
@onready var panel_desc: PanelContainer
@onready var extra_margin: MarginContainer

@onready var lbl_rarity: Label
@onready var pic_rarity: TextureRect
@onready var box_rarity: HBoxContainer

@onready var pic_item: TextureRect

@onready var box_bundle: HBoxContainer
@onready var panel_bundle: PanelContainer
@onready var lbl_bundle: Label

@onready var anim_player: AnimationPlayer
@onready var pic_card: TextureRect

@onready var panel_additional_info: Panel
@onready var panel_desktop: PanelContainer
@onready var panel_mobile: PanelContainer

var gamecolors: GameColors
var is_from_compendium: bool = false
var _is_mobile := OS.has_feature("mobile")
var _details_visible := false
var _refs_set: bool = false

var KEYWORDS: Dictionary = {}
var _trigger_regexes: Dictionary = {}
var _keyword_regexes: Dictionary = {}

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

const RARITY_COMMON    = preload("res://Resources/Rarity/common.tres")
const RARITY_UNCOMMON  = preload("res://Resources/Rarity/uncommon.tres")
const RARITY_RARE      = preload("res://Resources/Rarity/rare.tres")
const RARITY_LEGENDARY = preload("res://Resources/Rarity/legendary.tres")
const RARITY_MYSTIC    = preload("res://Resources/Rarity/mystic.tres")
const RARITY_GOLDEN    = preload("res://Resources/Rarity/golden.tres")
const RARITY_DIAMOND   = preload("res://Resources/Rarity/diamond.tres")
const RARITY_CRAFTED   = preload("res://Resources/Rarity/crafted.tres")

var current_item: Item = null
var current_entity = null  # player or enemy (for upgrade displaying on weapons)

var stat_item = preload("res://Scenes/Card/card_stat.tscn")
var category_item = preload("res://Scenes/Card/category_label.tscn")
var definition_box_scene = preload("res://Scenes/Elements/definition_box.tscn")
var set_bonus_box_scene = preload("res://Scenes/Card/set_bonus_box.tscn")

var pending_set_bonus: SetBonus = null
var stats_to_add: Dictionary = {}
var definition_boxes: Array[Control] = []
var _cached_categories: Array[String] = []
var _cached_stats: Dictionary = {}
var found_keywords = []
var pending_ingredients: Array[Item] = []
var placement_side: String = "above"

func _init_keywords():
	KEYWORDS = {
		"acid": {
			"color": GameColors.stats.acid,
			"description": "Removes shield equal to acid at turn start.",
			"icon": CombatLog.ICON_ACID
		},
		"poison": {
			"color": GameColors.stats.poison,
			"description": "If you have no shield, take damage equal to poison at turn start and remove 1 stack.",
			"icon": CombatLog.ICON_POISON
		},
		"burn": {
			"color": GameColors.stats.burn,
			"description": "At turn end, take damage equal to enemy's burn damage stat and remove 1 burn stack.",
			"icon": CombatLog.ICON_BURN
		},
		"thorns": {
			"color": GameColors.stats.thorns,
			"description": "Deal damage equal to your thorn stacks when hit, then remove them at turn end. ",
			"icon": CombatLog.ICON_THORNS
		},
		"regeneration": {
			"color": GameColors.stats.regeneration,
			"description": "Restore health equal to regeneration at turn end, then remove 1 stack.",
			"icon": CombatLog.ICON_REGEN
		},
		"stun": {
			"color": GameColors.stats.stun,
			"description": "Skip your next weapon strike and remove 1 stun.",
			"icon": CombatLog.ICON_STUN
		},	
		"stunned": {
			"color": GameColors.stats.stun,
			"description": "Skip your next weapon strike and remove 1 stun.",
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
			"description": "Your attack is halved (15+ stacks it is thirded). Remove 1 stack at turn end.",
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

	for keyword in KEYWORDS:
		var rx = RegEx.new()
		rx.compile("(?i)\\b" + keyword + "\\b")
		_keyword_regexes[keyword] = rx

func _unhandled_input(event: InputEvent) -> void:
	if is_from_compendium or _is_mobile:
		return
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		if event.pressed and not _details_visible:
			_details_visible = true
			create_stacked_definitions()
		elif not event.pressed and _details_visible:
			_details_visible = false
			_hide_definitions()
			
func set_references():
	if _refs_set:
		return
	_refs_set = true
	
	panel_container = $Panel/Control/PanelContainer
	panel = $Panel

	lbl_name = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/NameRarityArea/NameAndBundle/lblName

	lbl_rarity = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/NameRarityArea/rarityContainer/lblRarity
	pic_rarity = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/NameRarityArea/rarityContainer/picRarity
	box_rarity = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/NameRarityArea/rarityContainer

	pic_item = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/ImageStatsArea/PanelContainer/picBorderItem/picItem
	stats_grid = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/ImageStatsArea/VBoxContainer/statContainer

	lbl_desc = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/ImageStatsArea/VBoxContainer/panelDesc/MarginContainer/VBoxContainer/txtDesc
	category_grid = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/BottomPart/MarginContainer2/categoryGrid
	txt_upgrades = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/ImageStatsArea/VBoxContainer/panelDesc/MarginContainer/VBoxContainer/txtUpgrades
	panel_desc = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/ImageStatsArea/VBoxContainer/panelDesc
	extra_margin = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/ImageStatsArea/VBoxContainer/marginExtra

	lbl_bundle = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/NameRarityArea/NameAndBundle/boxBundle/panelBundle/lblBundle
	panel_bundle = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/NameRarityArea/NameAndBundle/boxBundle/panelBundle
	box_bundle = $Panel/Control/PanelContainer/MarginContainer/VBoxContainer/NameRarityArea/NameAndBundle/boxBundle

	anim_player = $AnimationPlayer
	pic_card = $Panel/Control/PanelContainer/cardBack

	panel_additional_info = $Panel/Control/panelAdditional
	panel_desktop = panel_additional_info.get_node("panelDesktop")
	panel_mobile = panel_additional_info.get_node("panelMobile")

	gamecolors = GameColors.new()
	if KEYWORDS.is_empty():
		_init_keywords()

	for trigger in TRIGGER_KEYWORDS:
		var rx = RegEx.new()
		rx.compile("(?i)\\b" + trigger + "\\b")
		_trigger_regexes[trigger] = rx


func set_item(this_item: Item, create_definitions: bool = true, entity = null):
	set_references()
	clear_definition_boxes()

	current_item = this_item
	current_entity = entity

	lbl_name.text = this_item.item_name
	pic_item.texture = this_item.item_icon
	pic_item.modulate = this_item.item_color

	if entity:
		if entity.current_weapon_rule_upgrade && this_item.item_type == Item.ItemType.WEAPON:
			lbl_name.text = entity.current_weapon_rule_upgrade.item_name + " " + this_item.item_name

	set_rarity()
	get_stat_bonuses()

	show_description(this_item, create_definitions, entity)
	set_upgrades()
	show_stats()
	show_categories(this_item.categories)
	set_bundle()
	
	if this_item.item_type == Item.ItemType.SET_BONUS:
		set_bonus()

func set_bonus():
	lbl_rarity.text = " Set Bonus"
	box_rarity.modulate = Color.WHITE
	if current_item && current_item != null:
		box_rarity.modulate = current_item.item_color
	pic_rarity.visible = false
	category_grid.visible = false

func set_tooltip_position(_pos: Vector2):
	global_position = _pos

func set_bonus_ingredients(_items: Array[Item]):
	pending_ingredients = _items.duplicate()

func set_pending_set_bonus(sb: SetBonus) -> void:
	pending_set_bonus = sb

func set_bundle():
	if is_from_compendium:
		box_bundle.visible = true
		panel_bundle.modulate = gamecolors.get_bundle_color(current_item.item_bundle)
		lbl_bundle.text = Enums.get_bundle_string(current_item.item_bundle)
	else:
		box_bundle.visible = false

func set_upgrades():
	txt_upgrades.visible = false
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
		panel_desc.show()
		show_extra_margin()
		txt_upgrades.visible = true
		txt_upgrades.text = "It's covered in" + str_upgrades + ".\n"

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
	show_extra_margin()

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
		panel_desc.visible = true
		show_extra_margin()
	else:
		lbl_desc.hide()
		panel_desc.visible = false
		show_extra_margin()

func show_extra_margin():
	var showing_cnt: int = 0

	if stats_grid.visible:
		showing_cnt += 1
	if panel_desc.visible:
		showing_cnt += 1

	if showing_cnt == 1:
		extra_margin.visible = true
	else:
		extra_margin.visible = false

func show_stats():
	if stats_to_add.size() == 0:
		if stats_grid.get_child_count() > 0:
			for child in stats_grid.get_children():
				child.queue_free()
			_cached_stats.clear()
		stats_grid.hide()
		return

	if stats_to_add == _cached_stats:
		stats_grid.show()
		return
	_cached_stats = stats_to_add.duplicate()

	stats_grid.show()

	var existing := stats_grid.get_children()
	var existing_count := existing.size()
	var keys := stats_to_add.keys()
	var new_count := keys.size()

	for i in range(new_count):
		var key = keys[i]
		if i < existing_count:
			existing[i].update_stat(stats_to_add[key].name, int(stats_to_add[key].value))
		else:
			var stat = stat_item.instantiate()
			stat.update_stat(stats_to_add[key].name, int(stats_to_add[key].value))
			stat.custom_minimum_size = Vector2(54, 78)
			stats_grid.add_child(stat)

	for i in range(new_count, existing_count):
		existing[i].queue_free()

func show_categories(categories: Array[String]):
	if categories == _cached_categories:
		category_grid.visible = categories.size() > 0
		return
	_cached_categories = categories.duplicate()

	var existing := category_grid.get_children()
	var existing_count := existing.size()
	var new_count := categories.size()

	if new_count == 0:
		for child in existing:
			child.queue_free()
		category_grid.hide()
		return

	category_grid.columns = 4

	for i in range(new_count):
		var category := categories[i]
		var cat_container: Control
		if i < existing_count:
			cat_container = existing[i]
		else:
			cat_container = category_item.instantiate()
			category_grid.add_child(cat_container)

		var lbl: Label = cat_container.get_node("MarginContainer/lblCategory")
		lbl.text = category
		var font := lbl.get_theme_font("font")
		var font_size := lbl.get_theme_font_size("font_size")
		var text_width := font.get_string_size(category, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		cat_container.custom_minimum_size = Vector2(text_width + 60, 25)

		var btn = cat_container.get_node("MarginContainer/Button")
		btn.tooltip_text = ""
		if category == "Unique":
			btn.tooltip_text = "Can only equip one of this item."
		elif category == "Singularity":
			btn.tooltip_text = "Only one Singularity item equippable at a time."

	for i in range(new_count, existing_count):
		existing[i].queue_free()

	category_grid.show()

func _hide_definitions() -> void:
	for box in definition_boxes:
		box.queue_free()
	definition_boxes.clear()
	if is_instance_valid(panel_additional_info):
		panel_additional_info.visible = true

func process_description(text: String) -> String:
	var processed_text = text
	var keywords_in_text = []

	for trigger in TRIGGER_KEYWORDS:
		var color = TRIGGER_KEYWORDS[trigger]
		# Case-insensitive replacement
		var regex = _trigger_regexes[trigger]
		var matches = regex.search_all(processed_text)
		
		# Process matches in reverse to maintain string positions
		for i in range(matches.size() - 1, -1, -1):
			var match = matches[i]
			var original = match.get_string()
			var replacement = "[color=%s][b]%s[/b][/color]" % [color, original]
			processed_text = processed_text.substr(0, match.get_start()) + replacement + processed_text.substr(match.get_end())
 
	# find the keywords so we can define them later
	for keyword in KEYWORDS:
		var regex = _keyword_regexes[keyword]
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
		var regex = _keyword_regexes[keyword]
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
	var def_box_width: float = 410.0
	var def_box_height: float = 110.0

	# First definition box bottom should be flush with tooltip bottom
	var y_offset = panel_container.position.y + panel_container.size.y - def_box_height

	if is_instance_valid(panel_additional_info):
		panel_additional_info.visible = false

	## -- KEYWORD LOOP
	var keywords_snapshot: Array = found_keywords.duplicate()
	for i in range(keywords_snapshot.size()):
		var keyword = keywords_snapshot[i]
		if keyword not in KEYWORDS:
			continue
		
		var def_box = definition_box_scene.instantiate()
		panel.add_child(def_box)
		def_box.setup(keyword, KEYWORDS[keyword].description, KEYWORDS[keyword].color)
		def_box.set_min_width(def_box_width)

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
		var use_right_side: bool
		match placement_side:
			"left":
				# Card is left of item — push defs further left, away from item
				use_right_side = false
				if space_on_left < (def_box_width + extra_spacing + 10):
					use_right_side = true  # no room, fall back
			"right":
				# Card is right of item — push defs further right, away from item
				use_right_side = true
				if space_on_right < (def_box_width + extra_spacing + 10):
					use_right_side = false  # no room, fall back
			_:
				# Above or below — use available space as before
				use_right_side = (space_on_right >= space_on_left)
				if use_right_side and space_on_right < (def_box_width + extra_spacing + 10):
					if space_on_left >= (def_box_width + extra_spacing + 10):
						use_right_side = false
				elif not use_right_side and space_on_left < (def_box_width + extra_spacing + 10):
					if space_on_right >= (def_box_width + extra_spacing + 10):
						use_right_side = true
		if use_right_side:
			def_box.position = Vector2(pos_right_x, y_offset)
		else:
			def_box.position = Vector2(pos_left_x, y_offset)

		definition_boxes.append(def_box)
		def_box.show_def()

		# Stack upward for next box (negative y since Panel is bottom-anchored)
		if i < keywords_snapshot.size() - 1:  # If not the last one
			y_offset -= (def_box_height + extra_spacing)

	## -- INGREDIENT LOOP
	var ingredient_box_width: float = 250.0

	# Offset past the last keyword box before stacking ingredients
	if keywords_snapshot.size() > 0:
		y_offset -= (def_box_height + extra_spacing)

	for i in range(pending_ingredients.size() - 1, -1, -1):
		var ingredient = pending_ingredients[i]
		
		var def_box = definition_box_scene.instantiate()
		def_box.custom_minimum_size = Vector2(ingredient_box_width, 0)
		panel.add_child(def_box)
		def_box.setup("Ingredient " + str(i + 1), ingredient.item_name, ingredient.item_color)
		if ingredient.item_icon:
			def_box.show_pic(ingredient.item_icon, ingredient.item_color)
		
		await get_tree().process_frame
		if not is_instance_valid(panel):
			return
		
		var viewport_size = get_viewport().get_visible_rect().size
		var tooltip_global_x = global_position.x
		var tooltip_width = panel_container.size.x
		var space_on_left = tooltip_global_x
		var space_on_right = viewport_size.x - (tooltip_global_x + tooltip_width)
		var pos_right_x = tooltip_width + extra_spacing
		var pos_left_x = -ingredient_box_width - extra_spacing
		
		var use_right_side: bool
		match placement_side:
			"left":
				# Card is left of item — push defs further left, away from item
				use_right_side = false
				if space_on_left < (def_box_width + extra_spacing + 10):
					use_right_side = true  # no room, fall back
			"right":
				# Card is right of item — push defs further right, away from item
				use_right_side = true
				if space_on_right < (def_box_width + extra_spacing + 10):
					use_right_side = false  # no room, fall back
			_:
				# Above or below — use available space as before
				use_right_side = (space_on_right >= space_on_left)
				if use_right_side and space_on_right < (def_box_width + extra_spacing + 10):
					if space_on_left >= (def_box_width + extra_spacing + 10):
						use_right_side = false
				elif not use_right_side and space_on_left < (def_box_width + extra_spacing + 10):
					if space_on_right >= (def_box_width + extra_spacing + 10):
						use_right_side = true
		if use_right_side:
			def_box.position = Vector2(pos_right_x, y_offset)
		else:
			def_box.position = Vector2(pos_left_x, y_offset)

		definition_boxes.append(def_box)
		def_box.show_def()
		y_offset -= (def_box_height + extra_spacing)

	## -- SET BONUS BLOCK
	if pending_set_bonus and current_item.item_type != Item.ItemType.SET_BONUS:
		var set_box_width: float = 334.0

		var sb_box = set_bonus_box_scene.instantiate()
		sb_box.setup(pending_set_bonus.setbonus_name, pending_set_bonus.setbonus_item.item_color)
		sb_box.set_min_width(set_box_width)
		panel.add_child(sb_box)
		sb_box.set_ingredients(pending_set_bonus)

		await get_tree().process_frame
		if not is_instance_valid(panel):
			return

		var sb_actual_height: float = sb_box.size.y
		var sb_actual_width: float = sb_box.size.x
		if sb_actual_height <= 0:
			sb_actual_height = 220.0  # fallback if layout hasn't resolved
		var sb_y_offset: float = y_offset + def_box_height - sb_actual_height

		var viewport_size = get_viewport().get_visible_rect().size
		var tooltip_global_x = global_position.x
		var tooltip_width = panel_container.size.x
		var space_on_left = tooltip_global_x
		var space_on_right = viewport_size.x - (tooltip_global_x + tooltip_width)
		var pos_right_x = tooltip_width + extra_spacing
		var pos_left_x = -sb_actual_width - extra_spacing

		var use_right_side: bool
		match placement_side:
			"left":
				use_right_side = false
				if space_on_left < (sb_actual_width + extra_spacing + 10):
					use_right_side = true
			"right":
				use_right_side = true
				if space_on_right < (sb_actual_width + extra_spacing + 10):
					use_right_side = false
			_:
				use_right_side = (space_on_right >= space_on_left)
				if use_right_side and space_on_right < (sb_actual_width + extra_spacing + 10):
					if space_on_left >= (sb_actual_width + extra_spacing + 10):
						use_right_side = false
				elif not use_right_side and space_on_left < (sb_actual_width + extra_spacing + 10):
					if space_on_right >= (sb_actual_width + extra_spacing + 10):
						use_right_side = true

		if use_right_side:
			sb_box.position = Vector2(pos_right_x, sb_y_offset)
		else:
			sb_box.position = Vector2(pos_left_x, sb_y_offset)

		definition_boxes.append(sb_box)
		sb_box.show_def()

func clear_definition_boxes():
	for box in definition_boxes:
		box.queue_free()
	definition_boxes.clear()
	found_keywords.clear()
	pending_ingredients.clear()
	pending_set_bonus = null

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
	var rarity_color: Color = Color.WHITE

	if current_item.rarity == Enums.Rarity.COMMON:
		rarity_color = gamecolors.rarity.common
		pic_rarity.texture = RARITY_COMMON
		lbl_rarity.text = " Common"
	elif current_item.rarity == Enums.Rarity.UNCOMMON:
		rarity_color =  gamecolors.rarity.uncommon
		pic_rarity.texture = RARITY_UNCOMMON
		lbl_rarity.text = " Uncommon"
	elif current_item.rarity == Enums.Rarity.RARE:
		rarity_color =  gamecolors.rarity.rare
		pic_rarity.texture = RARITY_RARE
		lbl_rarity.text = " Rare"
	elif current_item.rarity == Enums.Rarity.LEGENDARY:
		rarity_color =  gamecolors.rarity.legendary
		pic_rarity.texture = RARITY_LEGENDARY
		lbl_rarity.text = " Legendary"
	elif current_item.rarity == Enums.Rarity.GOLDEN:
		rarity_color =  gamecolors.rarity.golden
		pic_rarity.texture = RARITY_GOLDEN
		lbl_rarity.text = " Golden"
	elif current_item.rarity == Enums.Rarity.DIAMOND:
		rarity_color=  gamecolors.rarity.diamond
		pic_rarity.texture = RARITY_DIAMOND
		lbl_rarity.text = " Diamond"
	elif current_item.rarity == Enums.Rarity.CRAFTED:
		rarity_color =  gamecolors.rarity.crafted
		pic_rarity.texture = RARITY_CRAFTED
		lbl_rarity.text = " Crafted"
	else:
		rarity_color =  Color.GRAY
		lbl_rarity.text = " Unknown"
		pic_rarity.visible = false

	lbl_rarity.text += " " + set_item_type_desc()
	box_rarity.modulate = rarity_color
	set_outline_color(rarity_color)

func show_card():
	_setup_details_hint()
	anim_player.play("show_tooltip")

func play_card_idle():
	pass
	#anim_player.play("card_idle")

func set_outline_color(_color: Color):
	var image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, _color)
	var texture = ImageTexture.create_from_image(image)
	pic_card.material.set_shader_parameter("color", texture)
	#pic_card.material.set_shader_parameter("color", _color)

func _setup_details_hint():
	if is_from_compendium:
		panel_additional_info.visible = false
		return
	var has_definitions := found_keywords.size() > 0 or pending_ingredients.size() > 0 or pending_set_bonus != null
	panel_additional_info.visible = has_definitions
	if has_definitions:
		panel_desktop.visible = !_is_mobile
		panel_mobile.visible = _is_mobile

func set_item_type_desc() -> String:
	if current_item:
		match current_item.item_type:
			Item.ItemType.BODY_ARMOR:
				return "Armor"
			Item.ItemType.BOOTS:
				return "Boots"
			Item.ItemType.GLOVES:
				return "Gloves"
			Item.ItemType.HELMET:
				return "Helmet"
			Item.ItemType.BELT:
				return "Belt"
			Item.ItemType.SHIELD:
				return "Shield"
			Item.ItemType.POTION:
				return "Potion"
			Item.ItemType.JEWELRY:
				return "Jewelry"
			Item.ItemType.WEAPON:
				return "Weapon"
			Item.ItemType.BUG:
				return "Bug"
			_:
				return "Tool"
	return ""
