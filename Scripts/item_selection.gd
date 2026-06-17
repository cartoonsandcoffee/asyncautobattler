extends Control
class_name ItemSelection

signal item_selected(slot: ItemSelection)
signal item_purchased(item: ItemSelection)

enum ChoiceType {
	REWARD,
	PURCHASE
}

@onready var main_panel: PanelContainer
@onready var anim_hover: AnimationPlayer
@onready var anim_main: AnimationPlayer
@onready var anim_upgrade: AnimationPlayer

@onready var item_icon: TextureRect 
@onready var pic_rarity: TextureRect
@onready var button: Button

@onready var box_cost: HBoxContainer
@onready var lbl_price: Label
@onready var price_container: PanelContainer

@onready var pnl_selected: Panel
@onready var anim_select: AnimationPlayer

@export var choice_type: ChoiceType = ChoiceType.REWARD
@export var current_item: Item = null
@export var item_cost: int = 0

const RARITY_COMMON    = preload("res://Resources/Rarity/common.tres")
const RARITY_UNCOMMON  = preload("res://Resources/Rarity/uncommon.tres")
const RARITY_RARE      = preload("res://Resources/Rarity/rare.tres")
const RARITY_LEGENDARY = preload("res://Resources/Rarity/legendary.tres")
const RARITY_MYSTIC    = preload("res://Resources/Rarity/mystic.tres")
const RARITY_GOLDEN    = preload("res://Resources/Rarity/golden.tres")
const RARITY_DIAMOND   = preload("res://Resources/Rarity/diamond.tres")
const RARITY_CRAFTED   = preload("res://Resources/Rarity/crafted.tres")
const BANISH_MATERIAL = preload("res://Shaders/banish_shader_material.tres")

var item_instance_id: int = -1  # Track the specific instance
var slot_index: int = 10  # to track position

var default_grey: Color = Color("#9b9b9b")
var gamecolors: GameColors

var has_been_selected: bool = false
var can_afford_item: bool = false

var use_selection_mode: bool = false
var is_selected: bool = false
var _refs_set: bool = false
var hover_enabled: bool = true

## - JDM: For long-press tooltips on mobile only
const LONG_PRESS_DURATION := 1.0
var _long_press_timer: float = 0.0
var _long_press_active: bool = false
var _is_mobile := OS.has_feature("mobile")

func _ready() -> void:
	set_references()

func _process(delta: float) -> void:
	if not _is_mobile or not _long_press_active:
		return
	_long_press_timer += delta
	if _long_press_timer >= LONG_PRESS_DURATION:
		_long_press_active = false
		TooltipManager.expand_current_tooltip_definitions()

func set_references():
	if _refs_set:
		return
	_refs_set = true
	
	gamecolors = GameColors.new()

	main_panel = $PanelItem
	item_icon = $PanelItem/picItem
	pic_rarity = $PanelItem/margRarity/picRarity
	button = $PanelItem/Button
	pnl_selected = $panelSelected

	anim_hover = $animHover
	anim_main = $animMain
	anim_upgrade = $animUpgrade
	anim_select = $animSelect
	
	lbl_price = $PanelCost/hboxCost/lblPrice
	price_container = $PanelCost
	box_cost = $PanelCost/hboxCost

	if not button.mouse_entered.is_connected(_on_button_mouse_entered):
		button.mouse_entered.connect(_on_button_mouse_entered)
	if not button.mouse_exited.is_connected(_on_button_mouse_exited):
		button.mouse_exited.connect(_on_button_mouse_exited)
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)
	if not button.button_down.is_connected(_on_button_down):
		button.button_down.connect(_on_button_down)
	if not button.button_up.is_connected(_on_button_up):
		button.button_up.connect(_on_button_up)

	if choice_type == ChoiceType.REWARD:
		price_container.visible = false
	elif  choice_type == ChoiceType.PURCHASE:
		price_container.visible = true

func set_item(item: Item):
	set_references()

	if item:
		current_item = item
		item_instance_id = item.instance_id  
		update_visuals()
		button.disabled = false
		if ItemsManager.player_has_duplicate(item, false):
			show_upgrade_anim()
		else:
			stop_upgrade_anim()
	else:
		set_empty()
	
func setup_for_store(_on_sale: bool = false):
	choice_type = ChoiceType.PURCHASE
	price_container.visible = true
	set_price(_on_sale)

func set_empty():
	current_item = null
	item_instance_id = -1 
	button.disabled = true
	pic_rarity.visible = false

func display_item():
	anim_main.play("appear")
	AudioManager.play_ui_sound("woosh")

func set_price(_on_sale: bool = false):
	if current_item:
		match current_item.rarity:
			Enums.Rarity.COMMON:
				item_cost = 3
			Enums.Rarity.UNCOMMON:
				item_cost = 5
			Enums.Rarity.RARE:
				item_cost = 10
			Enums.Rarity.LEGENDARY:
				item_cost = 20
			Enums.Rarity.GOLDEN:
				item_cost = 20
			Enums.Rarity.DIAMOND:
				item_cost = 40
			Enums.Rarity.CRAFTED:
				item_cost = 50
			_:
				item_cost = (randi_range(3,15))

		# First upgrade each weapon is free
		if current_item.item_type == Item.ItemType.UPGRADE:
			if Player.current_weapon_rule_upgrade != null:
				item_cost = 10
			else:
				item_cost = 0

	if _on_sale:
		lbl_price.modulate = Color.LIME_GREEN
		item_cost -= int(item_cost/2)

	lbl_price.text = str(item_cost)

func update_visuals():
	if current_item:
		item_icon.self_modulate = current_item.item_color
		if (current_item.item_type == Item.ItemType.WEAPON):
			set_weapon_text_color()
		else:
			set_item_type_desc()
		item_icon.texture = current_item.item_icon
		set_rarity_color()

func get_current_item() -> Item:
	return current_item

func set_item_type_desc():
	if current_item:
			item_icon.self_modulate = current_item.item_color

func set_rarity_color():
	if current_item.rarity == Enums.Rarity.COMMON:
		pic_rarity.texture = RARITY_COMMON
		pic_rarity.self_modulate = gamecolors.rarity.common
		pnl_selected.self_modulate = gamecolors.rarity.common
	elif current_item.rarity == Enums.Rarity.UNCOMMON:
		pic_rarity.texture = RARITY_UNCOMMON
		pic_rarity.self_modulate = gamecolors.rarity.uncommon
		pnl_selected.self_modulate = gamecolors.rarity.uncommon
	elif current_item.rarity == Enums.Rarity.RARE:
		pic_rarity.texture = RARITY_RARE
		pic_rarity.self_modulate = gamecolors.rarity.rare
		pnl_selected.self_modulate = gamecolors.rarity.rare
	elif current_item.rarity == Enums.Rarity.LEGENDARY:
		pic_rarity.texture = RARITY_LEGENDARY
		pic_rarity.self_modulate = gamecolors.rarity.legendary
		pnl_selected.self_modulate = gamecolors.rarity.legendary
	elif current_item.rarity == Enums.Rarity.MYSTERIOUS:
		pic_rarity.texture = RARITY_MYSTIC
		pic_rarity.self_modulate = gamecolors.rarity.mysterious
		pnl_selected.self_modulate = gamecolors.rarity.mysterious
	elif current_item.rarity == Enums.Rarity.GOLDEN:
		pic_rarity.texture = RARITY_GOLDEN
		pic_rarity.self_modulate = gamecolors.rarity.golden
		pnl_selected.self_modulate = gamecolors.rarity.golden
	elif current_item.rarity == Enums.Rarity.DIAMOND:
		pic_rarity.texture = RARITY_DIAMOND
		pic_rarity.self_modulate = gamecolors.rarity.diamond
		pnl_selected.self_modulate = gamecolors.rarity.diamond
	elif current_item.rarity == Enums.Rarity.CRAFTED:
		pic_rarity.texture = RARITY_CRAFTED
		pic_rarity.self_modulate = gamecolors.rarity.crafted
		pnl_selected.self_modulate = gamecolors.rarity.crafted

func set_weapon_text_color():
	pass

func get_item_instance() -> Item:
	# Return the specific instance, not just any item
	if current_item and current_item.instance_id == item_instance_id:
		return current_item
	return null

func cannot_afford():
	box_cost.modulate = Color.RED
	main_panel.modulate.a = 0.4
	can_afford_item = false
	#button.disabled = true

func enable_button():
	button.disabled = false

func can_afford():
	can_afford_item = true
	button.disabled = false
	box_cost.visible = true
	box_cost.modulate = Color("#ffbb00")
	main_panel.modulate.a = 1

func _on_button_mouse_exited() -> void:
	_long_press_active = false
	CursorManager.reset_cursor()
	TooltipManager.hide_tooltip() 

func start_item_hover_anim():
	anim_hover.play("hover")

func _on_button_mouse_entered() -> void:
	if not hover_enabled:
		return

	## - JDM: Mobile long tap
	if _is_mobile and current_item:
		_long_press_active = true
		_long_press_timer = 0.0

	if current_item:  # Only if slot has item
		AudioManager.play_ui_sound("item_hover")	
		CursorManager.set_interact_cursor()
	if !button.disabled:
		#anim_hover.play("hover")
		TooltipManager.show_item_tooltip(current_item, global_position, size)

func _on_button_down() -> void:
	if _is_mobile and current_item:
		_long_press_active = true
		_long_press_timer = 0.0

func _on_button_up() -> void:
	_on_button_mouse_exited()

func _on_button_pressed() -> void:
	if has_been_selected:
		return

	# Selection mode: signal click, let parent commit the action
	if use_selection_mode:
		item_selected.emit(current_item)
		return

	# Purchase guard only relevant outside selection mode
	if !can_afford_item && choice_type == ChoiceType.PURCHASE:
		AudioManager.play_random_voice_no()
		return

	if current_item:  # Only if slot has item
		if choice_type == ChoiceType.REWARD:
			AudioManager.play_ui_sound("item_pickup")
		elif choice_type == ChoiceType.PURCHASE:
			AudioManager.play_event_sound("coins_02")

	has_been_selected = true
	button.disabled = true
	
	if choice_type == ChoiceType.REWARD:
		item_selected.emit(current_item)
	elif choice_type == ChoiceType.PURCHASE:
		item_purchased.emit(self)

func show_upgrade_anim():
	if current_item.rarity == Enums.Rarity.COMMON:
		anim_upgrade.play("show_gold")
	elif current_item.rarity == Enums.Rarity.GOLDEN:
		anim_upgrade.play("show_diamond")

func stop_upgrade_anim():
	anim_upgrade.play("RESET")

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		anim_select.play("select_grow")
		anim_main.play("selected")
		anim_hover.pause()
	else:
		anim_select.play("select_shrink")
		anim_main.play("un_selected")
		anim_hover.play()

func confirm_selection() -> void:
	has_been_selected = true
	button.disabled = true

func banish_me():
	var mat = BANISH_MATERIAL.duplicate()
	item_icon.material = mat
	mat.set_shader_parameter("item_color", item_icon.self_modulate)

	AudioManager.play_ui_sound("banish")
	var tween = create_tween()
	tween.tween_method(func(v): mat.set_shader_parameter("dissolve_value", v), 1.0, 0.0, 1.0)
	await tween.finished
	item_icon.material = null
