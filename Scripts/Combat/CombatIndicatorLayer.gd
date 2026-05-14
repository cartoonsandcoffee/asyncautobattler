class_name CombatIndicatorLayer
extends Node

## Owns all floating indicator spawning during combat.
## Called directly from CombatEventQueue._process_event handlers only.
## Has no knowledge of combat logic or game state.

var combat_panel: CombatPanel

var item_proc_scene = preload("res://Scenes/Elements/combat_item_proc.tscn")

var player_pos: Vector2 = Vector2(422, 262)
var enemy_pos: Vector2 = Vector2(695, 180)
var pos_shift: int = 15

func initialize(panel: CombatPanel) -> void:
	combat_panel = panel

func _spawn_item_proc_indicator_immediate(item: Item, rule: ItemRule, entity, amount: int = 0, resolved_status: Enums.StatusEffects = Enums.StatusEffects.NONE) -> void:
	var combat_item_proc = item_proc_scene.instantiate()

	combat_item_proc.set_references()
	combat_item_proc.set_label(amount)
	combat_item_proc.set_info(Enums.get_trigger_type_string(rule.trigger_type))
	combat_item_proc.set_item_visuals(item.item_icon, item.item_color)

	if rule.effect_type == Enums.EffectType.MODIFY_STAT:
		combat_item_proc.set_stat_visuals(rule.target_stat)
	elif rule.effect_type == Enums.EffectType.HEAL:
		combat_item_proc.set_stat_visuals(Enums.Stats.HITPOINTS)
	elif rule.effect_type == Enums.EffectType.DEAL_DAMAGE:
		combat_item_proc.set_status_visuals(Enums.StatusEffects.BLEED)
		combat_item_proc._done()
		return  # Goes through combat damage system, no status proc needed
	elif rule.effect_type == Enums.EffectType.APPLY_STATUS:
		combat_item_proc.set_status_visuals(resolved_status)
	elif rule.effect_type == Enums.EffectType.REMOVE_STATUS:
		combat_item_proc.set_status_visuals(resolved_status)
	elif rule.effect_type == Enums.EffectType.CONVERT:
		if rule.convert_to_type == ItemRule.StatOrStatus.STAT:
			combat_item_proc.set_stat_visuals(rule.convert_to_stat)
		else:  # STATUS
			combat_item_proc.set_status_visuals(rule.convert_to_status)

	combat_panel.add_child(combat_item_proc)
	AudioManager.play_ui_sound("item_proc")

	var entity_name: String = CombatManager.get_entity_name(entity)
	var is_targeting_self: bool = rule.target_type == Enums.TargetType.SELF

	var target_is_player: bool = (entity_name == "Player" and is_targeting_self) or (entity_name != "Player" and not is_targeting_self)
	var pos = player_pos if target_is_player else enemy_pos
	combat_item_proc.position = pos + Vector2(randi_range(-pos_shift, pos_shift), 0)
	combat_item_proc.run_animation(Enums.Party.PLAYER)

func _spawn_status_proc_indicator_immediate(entity, _status: Enums.StatusEffects, _stat: Enums.Stats, value: int) -> void:
	var combat_item_proc = item_proc_scene.instantiate()

	combat_item_proc.set_references()
	combat_item_proc.set_label(value)
	combat_item_proc.set_info("Status Effect")
	combat_item_proc.set_status_as_item_visuals(_status)
	combat_item_proc.set_stat_visuals(_stat)

	combat_panel.add_child(combat_item_proc)
	AudioManager.play_ui_sound("item_proc")

	if entity == combat_panel.current_player_entity:
		combat_item_proc.position = player_pos + Vector2(randi_range(-pos_shift, pos_shift), 0)
	else:
		combat_item_proc.position = enemy_pos + Vector2(randi_range(-pos_shift, pos_shift), 0)
	combat_item_proc.run_animation(Enums.Party.PLAYER)

func _spawn_damage_indicator_immediate(target, amount: int, damage_stat: Enums.Stats, visual_info: Dictionary) -> void:
	var combat_item_proc = item_proc_scene.instantiate()

	combat_item_proc.set_references()
	combat_item_proc.set_label(amount * -1)
	combat_item_proc.set_info(visual_info.get("source_name", "Damage!"))

	if visual_info.has("status"):
		combat_item_proc.set_status_as_item_visuals(combat_panel._get_status_enum(visual_info.status))
	elif visual_info.has("icon") and visual_info.icon:
		combat_item_proc.set_item_visuals(visual_info.icon, visual_info.get("color", Color.WHITE))
	else:
		combat_item_proc.set_item_visuals(null, visual_info.get("color", Color.RED))

	combat_item_proc.set_stat_visuals(damage_stat)

	combat_panel.add_child(combat_item_proc)
	AudioManager.play_ui_sound("item_proc")

	if target == combat_panel.current_enemy_entity:
		combat_item_proc.global_position = enemy_pos + Vector2(randi_range(-pos_shift, pos_shift), 0)
		combat_item_proc.run_animation(Enums.Party.PLAYER)
		combat_panel._update_enemy_stats()
	else:
		combat_item_proc.global_position = player_pos + Vector2(randi_range(-pos_shift, pos_shift), 0)
		combat_item_proc.run_animation(Enums.Party.PLAYER)
		Player.stats.stats_updated.emit()

func _handle_status_box_update_immediate(entity, status: Enums.StatusEffects, stacks: int) -> void:
	var container = combat_panel.player_status_container if entity == combat_panel.current_player_entity else combat_panel.enemy_status_container

	var existing_box: StatusBox = null
	for child in container.get_children():
		if child is StatusBox and child.status == status:
			existing_box = child
			break

	if stacks > 0:
		if existing_box:
			combat_panel._update_status_box_value(existing_box, stacks)
		else:
			combat_panel._create_status_box(container, status, stacks)
	else:
		if existing_box:
			combat_panel._remove_status_box(existing_box)

	if entity == combat_panel.current_enemy_entity:
		combat_panel._update_enemy_stats()
	elif entity == combat_panel.current_player_entity:
		combat_panel.main_game.set_player_stats()
