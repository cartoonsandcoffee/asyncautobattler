extends Node

var all_set_bonuses: Array[SetBonus] = []

# Track active sets per entity
var entity_active_sets: Dictionary = {}  # {entity: Array[SetBonus]}

signal set_bonuses_updated(entity)

func _ready():
	load_all_set_bonuses()

func load_all_set_bonuses():
	all_set_bonuses.clear()
	var dir = DirAccess.open("res://Resources/SetBonuses/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var set_bonus = load("res://Resources/SetBonuses/" + file_name)
				if set_bonus is SetBonus:
					if set_bonus.unlocked:
						all_set_bonuses.append(set_bonus)
			file_name = dir.get_next()

func check_set_bonuses(entity):
	# Check which set bonuses are active for this entity.
	var new_active_sets: Array[Item] = []
    
	# Get all items this entity has
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
    
	if entity == Player:
		# Player inventory
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
			if owned_item.item_name == required_item.item_name:
				found = true
				break
        
		if not found:
			return false
    
	return true

func get_active_set_bonuses(entity) -> Array[Item]:
	return entity_active_sets.get(entity, [])