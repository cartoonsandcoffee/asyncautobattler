extends Node

var all_set_bonuses: Array[SetBonus] = []

# Track active sets per entity
var entity_active_sets: Dictionary = {}  # {entity: Array[SetBonus]}

var _initialized: bool = false

signal set_bonuses_updated(entity)

func _ready():
	pass

func initialize():
	if _initialized:
		return
	_initialized = true

	load_all_set_bonuses()


func load_all_set_bonuses():
	all_set_bonuses.clear()
	get_all_files_from_directory("res://Resources/SetBonus_Recipes/", ".tres")

func get_all_files_from_directory(path : String, file_ext:= "", files := []):
	var resources = ResourceLoader.list_directory(path)
	for res in resources:
		#print(str(path+res))
		if res.ends_with("/"): 
			# recursive for sub-directories
			get_all_files_from_directory(path+res, file_ext, files)		
		elif file_ext && res.ends_with(file_ext): 
			files.append(path+res)
			var set_bonus = load(path+res) as SetBonus
			if set_bonus:
				all_set_bonuses.append(set_bonus)
			else:
				push_warning("[SetBonusManager] Failed to load set: " + res)	
	return files


func check_set_bonuses(entity):
	# Check which set bonuses are active for this entity.

	var new_active_sets: Array[Item] = []
	var owned_items: Array[Item] = _get_entity_items(entity)
	
	# Check each set bonus
	for set_bonus in all_set_bonuses:
		if _has_all_required_items(set_bonus, owned_items):
			new_active_sets.append(set_bonus.setbonus_item)
	
	entity_active_sets[entity] = new_active_sets
	set_bonuses_updated.emit(entity)

func _get_entity_items(entity) -> Array[Item]:
	# Get all items owned by this entity.
	var items: Array[Item] = []
	
	if entity:
		if entity.inventory.weapon_slot:
			items.append(entity.inventory.weapon_slot)
		
		for item in entity.inventory.item_slots:
			if item:
				items.append(item)
	
	# For PvP bosses loaded from Supabase - handled by BossHandler
	return items

func _has_all_required_items(set_bonus: SetBonus, owned_items: Array[Item]) -> bool:
	# Check if entity owns all required items for this set.
	for required_item in set_bonus.required_items:
		var found = false
		for owned_item in owned_items:
			# Match by item_name (since items are duplicated/instanced)
			#if owned_item.item_name == required_item.item_name:
			
			# Using "base_item_id" variable so gold and diamond items will still activate set bonuses
			if owned_item.get_base_id() == required_item.get_base_id():
				found = true
				break
		
		if not found:
			return false
	
	return true

func get_active_set_bonuses(entity) -> Array[Item]:
	return entity_active_sets.get(entity, [])

func get_set_bonuses_for_item_array(items: Array[Item]) -> Array[Item]:
	# Calculate set bonuses for a given array of items (not tied to any entity).
	# Used for UI displays like Hall of Champions build previews.
	# 
	# Returns: Array of SetBonus items that would be active with these items.

	var active_set_items: Array[Item] = []
	
	# Check each set bonus
	for set_bonus in all_set_bonuses:
		if _has_all_required_items(set_bonus, items):
			active_set_items.append(set_bonus.setbonus_item)
	
	return active_set_items
