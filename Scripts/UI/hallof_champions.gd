extends Control

@onready var list_container: GridContainer = $Panel/PanelContainer/MarginContainer/mainBox/leftBox/VBoxContainer/PanelContainer/ScrollContainer/GridContainer
@onready var tab_description: Label = $Panel/PanelContainer/MarginContainer/mainBox/leftBox/VBoxContainer/lblMenu

@onready var build_box: HBoxContainer = $Panel/PanelContainer/MarginContainer/mainBox/rightBox/buildBox
@onready var weapon: GridContainer = $Panel/PanelContainer/MarginContainer/mainBox/rightBox/buildBox/boxInventory/weapon/GridContainer
@onready var inventory: GridContainer = $Panel/PanelContainer/MarginContainer/mainBox/rightBox/buildBox/boxInventory/InventoryGrid
@onready var set_bonuses: GridContainer = $Panel/PanelContainer/MarginContainer/mainBox/rightBox/buildBox/boxStats/setbonusBox
@onready var weapon_upgrades: HBoxContainer = $Panel/PanelContainer/MarginContainer/mainBox/rightBox/buildBox/boxStats/weaponUpgrades

@onready var btn_champions: Button = $Panel/PanelContainer/MarginContainer/mainBox/leftBox/VBoxContainer/boxButtons/btnChampions
@onready var btn_my_hall: Button = $Panel/PanelContainer/MarginContainer/mainBox/leftBox/VBoxContainer/boxButtons/btnHallOfFame
@onready var btn_global_hall: Button = $Panel/PanelContainer/MarginContainer/mainBox/leftBox/VBoxContainer/boxButtons/btnGlobalHall
@onready var btn_leaderboard: Button = $Panel/PanelContainer/MarginContainer/mainBox/leftBox/VBoxContainer/boxButtons/btnLeaderboard
@onready var btn_current_champs: Button = $Panel/PanelContainer/MarginContainer/mainBox/leftBox/VBoxContainer/boxButtons/btnGlobalChamps

# Stats Controls
@onready var stat_health: Control = $Panel/PanelContainer/MarginContainer/mainBox/rightBox/buildBox/boxStats/statBoxes/statHealth
@onready var stat_shield: Control = $Panel/PanelContainer/MarginContainer/mainBox/rightBox/buildBox/boxStats/statBoxes/statShield
@onready var stat_attack: Control = $Panel/PanelContainer/MarginContainer/mainBox/rightBox/buildBox/boxStats/statBoxes/statAttack
@onready var stat_agility: Control = $Panel/PanelContainer/MarginContainer/mainBox/rightBox/buildBox/boxStats/statBoxes/statAgility


const TAB_DESC = {
	"my_champions": "Your active and fallen champions.",
	"my_hall": "Your undefeated Hall of Fame legends (10-0).",
	"global_hall": "The 100 most recent 10-0 champions across all players.",
	"leaderboard": "Top 50 players ranked by champions killed.",
	"active_champions": "The current undefeated champions awaiting challengers."
}

var champion_record = preload("res://Scenes/Elements/champion_record.tscn")
var player_record = preload("res://Scenes/Elements/player_record.tscn")

var _cache: Dictionary = {}   # {tab_name: Array}
var _current_tab: String = ""
var _loaded_items_cache: Dictionary = {}  # {build_id: {items: Array[Item], sets: Array[Item]}}

func _ready() -> void:
	#_switch_tab("my_champions")
	set_buttons()
	build_box.visible = false

func set_buttons():
	btn_champions.pressed.connect(_switch_tab.bind("my_champions"))
	btn_my_hall.pressed.connect(_switch_tab.bind("my_hall"))
	btn_global_hall.pressed.connect(_switch_tab.bind("global_hall"))
	btn_leaderboard.pressed.connect(_switch_tab.bind("leaderboard"))
	btn_current_champs.pressed.connect(_switch_tab.bind("active_champions"))

	btn_champions.mouse_entered.connect(button_hover.bind("my_champions"))
	btn_my_hall.mouse_entered.connect(button_hover.bind("my_hall"))
	btn_global_hall.mouse_entered.connect(button_hover.bind("global_hall"))
	btn_leaderboard.mouse_entered.connect(button_hover.bind("leaderboard"))
	btn_current_champs.mouse_entered.connect(button_hover.bind("active_champions"))

	btn_champions.mouse_exited.connect(button_exit)
	btn_my_hall.mouse_exited.connect(button_exit)
	btn_global_hall.mouse_exited.connect(button_exit)
	btn_leaderboard.mouse_exited.connect(button_exit)
	btn_current_champs.mouse_exited.connect(button_exit)

func _switch_tab(tab: String) -> void:
	if _current_tab == tab:
		return
	_current_tab = tab
	tab_description.text = TAB_DESC[tab]
	#_clear_right_panel()
	if _cache.has(tab):
		_populate_list(tab, _cache[tab])
	else:
		_fetch_and_populate(tab)

func button_hover(tab: String) -> void:
	tab_description.text = TAB_DESC[tab]

func button_exit() -> void:
	tab_description.text = ""

func _fetch_and_populate(tab: String) -> void:
	_clear_list()
	var loading = Label.new()
	loading.text = "Loading..."
	list_container.add_child(loading)

	var data: Array = []
	match tab:
		"my_champions":
			var result = await SupabaseManager.get_player_champions(Player.player_uuid)
			# Merge active + dead, sort by created_at desc
			data = result.active + result.dead
			data.sort_custom(func(a, b): return a.created_at > b.created_at)
		"my_hall":
			var result = await SupabaseManager.get_player_champions(Player.player_uuid)
			data = result.hall_of_fame
		"global_hall":
			data = await SupabaseManager.get_global_hall_of_fame(100)
		"leaderboard":
			var r = await SupabaseManager._supabase_get(
				"/rest/v1/player_profiles?select=*,player_champion_stats(*)"
				+ "&order=champions_killed.desc,ears_balance.desc&limit=50"
			)
			# Then flatten the joined data
			for player in r.data:
				var stats = player.get("player_champion_stats", [])
				if stats.size() > 0:
					player["hall_champions_count"] = stats[0].get("hall_champions_count", 0)
					player["active_champions_count"] = stats[0].get("active_champions_count", 0)
				else:
					player["hall_champions_count"] = 0
					player["active_champions_count"] = 0
			data = r.data if r.status == 200 else []
		"active_champions":
			# NEW: Get all active champions (current champion pool)
			var r = await SupabaseManager._supabase_get(
				"/rest/v1/active_champions?limit=100"
			)
			data = r.data if r.status == 200 else []

	_cache[tab] = data

	# ── BULK LOAD ALL ITEMS FOR THIS TAB ────────────────────────
	await _preload_all_items_for_builds(data)

	_populate_list(tab, data)


func _clear_list() -> void:
	for c in list_container.get_children():
		c.queue_free()

func _preload_all_items_for_builds(builds: Array) -> void:
	"""Load all ItemResource objects for all builds in this tab."""
	var loading_count = 0
	var total_builds = builds.size()
	
	for build in builds:
		var build_id = build.get("id", "")
		if build_id.is_empty():
			continue
			
		# Parse and load items
		var all_items: Array[Item] = []
		
		# Load weapon
		var weapon_data = build.get("weapon", {})
		if weapon_data is String and not weapon_data.is_empty():
			weapon_data = JSON.parse_string(weapon_data)
		if not weapon_data.is_empty():
			var weapon = ItemsManager.get_item(weapon_data.get("id", ""))
			if weapon:
				all_items.append(weapon)
		
		# Load inventory
		var inv_data = build.get("inventory", [])
		if inv_data is String and not inv_data.is_empty():
			inv_data = JSON.parse_string(inv_data)
		if inv_data != null:
			for item_data in inv_data:
				if item_data and item_data.has("id"):
					var item = ItemsManager.get_item(item_data.get("id", ""))
					if item:
						all_items.append(item)
		
		# Calculate set bonuses
		var active_sets = SetBonusManager.get_set_bonuses_for_item_array(all_items)
		
		# Cache everything
		_loaded_items_cache[build_id] = {
			"items": all_items,
			"sets": active_sets
		}
		
		loading_count += 1
		
		# Update loading text every few builds
		if loading_count % 5 == 0:
			var loading_label = list_container.get_child(0) as Label
			if loading_label:
				loading_label.text = "Loading items... %d/%d" % [loading_count, total_builds]
			await get_tree().process_frame  # Let UI update

func _populate_list(tab: String, data: Array) -> void:
	_clear_list()
	if data.is_empty():
		var lbl = Label.new()
		lbl.text = "Nothing here yet."
		list_container.add_child(lbl)
		return

	match tab:
		"my_champions":    _build_my_champions_rows(data)
		"my_hall":         _build_hall_rows(data, false)
		"global_hall":     _build_hall_rows(data, true)
		"leaderboard":     _build_leaderboard_rows(data)
		"active_champions": _build_active_champions_rows(data)

func _build_active_champions_rows(data: Array) -> void:
	"""Display active champions (current pool)."""
	for build in data:
		var record = champion_record.instantiate()
		record.set_references()
		record.custom_minimum_size.y = 70
		
		var date_created = _format_date(build.get("created_at", ""))
		var username = build.get("username", "Unknown")
		var wins = build.get("champion_victories", 0)

		# Parse bundle array
		var bundle = _parse_bundle_array(build.get("item_bundles", [0, 0, 0]))
		
		record.set_bundle(bundle)
		# Use the global_hall format but with record instead of 2nd date
		record.set_fields_current_champs(date_created, int(wins), username)
		
		# Hover to show build details
		record.record_mouse_entered.connect(_show_build_details.bind(build))
		record.record_clicked.connect(_show_build_details.bind(build))
		record.mouse_filter = Control.MOUSE_FILTER_STOP
		list_container.add_child(record)

func _parse_bundle_array(bundle_data) -> Array[int]:
	var result: Array[int] = [0, 0, 0]
	
	var source: Array = []
	if bundle_data is String:
		var parsed = JSON.parse_string(bundle_data)
		source = parsed if parsed is Array else []
	elif bundle_data is Array:
		source = bundle_data
	
	for i in range(min(3, source.size())):
		result[i] = int(source[i])
	
	return result

func _build_my_champions_rows(data: Array) -> void:
	for build in data:
		var record = champion_record.instantiate()
		record.set_references()
		record.custom_minimum_size.y = 70
		
		var status = build.get("status", "")
		var is_active: bool = true if status == "active" else false
		var strdate = _format_date(build.get("created_at", ""))
		var strwins = str(build.get("champion_victories", 0))
		var bundle = _parse_bundle_array(build.get("item_bundles", [0, 0, 0]))

		record.set_bundle(bundle)
		record.set_active(is_active)
		record.set_fields_my_champions(strdate,strwins)

		# Hover to show build details
		record.record_mouse_entered.connect(_show_build_details.bind(build))
		record.mouse_filter = Control.MOUSE_FILTER_STOP

		list_container.add_child(record)

func _build_hall_rows(data: Array, show_player: bool) -> void:
	for build in data:
		var record = champion_record.instantiate()
		record.set_references()
		record.custom_minimum_size.y = 70

		var date1:String = _format_date(build.get("created_at", ""))
		var date2:String = _format_date(build.get("hall_of_fame_date", ""))
		var username:String = build.get("username", "Unknown")
		var bundle = _parse_bundle_array(build.get("item_bundles", [0, 0, 0]))

		record.set_bundle(bundle)
		
		if show_player:
			record.set_fields_global_hall(date1,date2,username)
		else:
			record.set_fields_hall_of_fame(date1,date2)

		record.mouse_entered.connect(_show_build_details.bind(build))
		record.mouse_filter = Control.MOUSE_FILTER_STOP
		list_container.add_child(record)

func _build_leaderboard_rows(data: Array) -> void:
	var my_id = Player.player_uuid
	
	for i in data.size():
		var p = data[i]
		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 28

		var player = player_record.instantiate()
		player.set_references()
		player.custom_minimum_size.y = 70
		
		if p.get("player_id", "") == my_id:
			player.its_me()
			
		var champs:int = p.get("hall_champions_count", 0)
		var actives:int = p.get("active_champions_count", 0)
		var runs:int = p.get("total_runs", 0)
		var kills:int = p.get("champions_killed", 0)
		var username:String = p.get("username", "Unknown")

		player.set_fields(username, runs, champs, actives, kills, (i + 1))

		list_container.add_child(player)


func _format_date(iso: String) -> String:
	if iso.is_empty(): return "—"
	return iso.substr(0, 10)  # "YYYY-MM-DD"


func _show_build_details(build: Dictionary) -> void:
	#_load_build_inventory(build)

	var build_id = build.get("id", "")
	_display_cached_items(build_id)
	
	build_box.visible = true

	var hp:int = build.get("max_hp", 0)
	var dmg:int = build.get("base_damage", 0)
	var shld:int = build.get("shield", 0)
	var agi:int = build.get("agility",0)

	stat_health.update_stat(Enums.Stats.HITPOINTS, hp, hp)
	stat_shield.update_stat(Enums.Stats.SHIELD, shld, shld)
	stat_attack.update_stat(Enums.Stats.DAMAGE, dmg, dmg)
	stat_agility.update_stat(Enums.Stats.AGILITY, agi, agi)


func _load_build_inventory(build: Dictionary) -> void:
	# Clear existing items
	for child in inventory.get_children():
		child.queue_free()

	for child in weapon.get_children():
		child.queue_free()

	# Parse inventory from database format
	var inv_data = build.get("inventory", [])
	if inv_data is String and not inv_data.is_empty():
		inv_data = JSON.parse_string(inv_data)
	if inv_data == null:
		inv_data = []
	
	# Parse weapon from database format
	var weapon_data = build.get("weapon", {})
	if weapon_data is String and not weapon_data.is_empty():
		weapon_data = JSON.parse_string(weapon_data)
	if weapon_data == null:
		weapon_data = {}
		
	var item_slot_scene = preload("res://Scenes/item.tscn")
	var all_items: Array[Item] = []  # ← Collect all items for set bonus calculation
	
	# Add weapon first (if exists)
	if not weapon_data.is_empty():
		var weapon_id = weapon_data.get("id", "")
		if not weapon_id.is_empty():
			var weapon_item = ItemsManager.get_item(weapon_id)
			if weapon_item:
				all_items.append(weapon_item)
				var weapon_slot = item_slot_scene.instantiate()
				weapon_slot.set_item(weapon_item)
				weapon_slot.set_is_from_compendium(true)
				weapon_slot.set_weapon_text_color() 
				weapon_slot.custom_minimum_size = Vector2(100, 120)  
				weapon.add_child(weapon_slot)
			else:
				print("[HallOfChampions] Warning: Weapon not found: ", weapon_id)
	
	# Add inventory items
	for i in range(inv_data.size()):
		var item_data = inv_data[i]
		if item_data and item_data.has("id"):
			var item_id = item_data.get("id", "")
			var item = ItemsManager.get_item(item_id)
			if item:
				all_items.append(item)
				var item_slot = item_slot_scene.instantiate()
				item_slot.set_item(item)
				item_slot.set_is_from_compendium(true)
				item_slot.set_order(i + 1)  # Show order number
				item_slot.custom_minimum_size = Vector2(100, 100)  # Smaller for UI
				inventory.add_child(item_slot)
			else:
				print("[HallOfChampions] Warning: Item not found: ", item_id)

	_show_set_bonuses(all_items)

func _display_cached_items(build_id: String) -> void:
	"""Instantly display pre-loaded items from cache."""
	# Clear existing items
	for child in inventory.get_children():
		child.queue_free()

	for child in weapon.get_children():
		child.queue_free()
	
	var cached = _loaded_items_cache.get(build_id, {})
	var items = cached.get("items", [])
	var sets = cached.get("sets", [])
	
	if items.is_empty():
		return
	
	var item_slot_scene = preload("res://Scenes/item.tscn")
	
	for item in items:
		var item_slot = item_slot_scene.instantiate()
		item_slot.set_item(item)
		item_slot.set_is_from_compendium(true)
		#item_slot.set_order(i + 1)  # Show order number
		item_slot.custom_minimum_size = Vector2(100, 100)  # Smaller for UI
		if item.item_type == Item.ItemType.WEAPON:
			item_slot.set_weapon_text_color()
			item_slot.custom_minimum_size = Vector2(100, 120)
			weapon.add_child(item_slot)
			continue
		inventory.add_child(item_slot)
	
	# Display set bonuses
	_show_set_bonuses(items)

func _show_set_bonuses(items: Array[Item]) -> void:
	"""Display set bonuses for the given item array."""
	var active_sets = SetBonusManager.get_set_bonuses_for_item_array(items)
	set_bonuses.visible = true

	if active_sets.is_empty():
		set_bonuses.visible = false
		return

	for child in set_bonuses.get_children():
		child.queue_free()

	var item_slot_scene = preload("res://Scenes/item.tscn")

	for bonus_item in active_sets:
		var item_container = item_slot_scene.instantiate()

		item_container.set_item(bonus_item)
		item_container.slot_index = -3
		item_container.custom_minimum_size = Vector2(100, 100)
		item_container.set_bonus() 
		set_bonuses.add_child(item_container)

func _on_btn_done_pressed() -> void:
	visible = false
