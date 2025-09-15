class_name CombatPanel
extends Control

## Combat overlay panel that slides in from the right side of the screen
## Manages combat UI, displays enemy/player stats, and highlights inventory items

signal combat_ui_ready()
signal player_chose_fight()
signal player_chose_run()
signal combat_completed(player_won: bool)
signal speed_changed(new_speed: CombatManager.CombatSpeed)

enum PanelState {
	HIDDEN,
	PRE_COMBAT,   # Shows enemy with fight/run buttons
	IN_COMBAT,    # Active combat with log and controls
	POST_COMBAT   # Victory/defeat screen
}

# UI References
@onready var enemy_name_label: Label = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/VBoxContainer/HBoxContainer/boxEnemyName/lblEnemy
@onready var enemy_desc_label: RichTextLabel = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/VBoxContainer/lblEnemyDesc
@onready var enemy_sprite: TextureRect = $picEnemy

@onready var box_fight_run: VBoxContainer = $LogPanel/RightSidePanel/PanelContainer/FightRunBox
@onready var box_combat_log: VBoxContainer = $LogPanel/RightSidePanel/PanelContainer/CombatLogBox

@onready var btn_run: Button = $LogPanel/RightSidePanel/PanelContainer/FightRunBox/btnRun

# Enemy stat displays
@onready var enemy_health_stat: StatBoxDisplay = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/statsContainer/statHealth
@onready var enemy_shield_stat: StatBoxDisplay = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/statsContainer/statShield
@onready var enemy_damage_stat: StatBoxDisplay = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/statsContainer/statDamage
@onready var enemy_agility_stat: StatBoxDisplay = $CombatPanelTop/PanelContainer/MarginContainer/VBoxContainer/enemyStats/statsContainer/statAgility
@onready var stat_container: PanelContainer = $CombatPanelTop/PanelContainer
@onready var enemy_status_box_container: HBoxContainer = $CombatPanelTop/panelStatus/statusBox

# Combat controls
@onready var speed_slider: HSlider = $LogPanel/RightSidePanel/PanelContainer/CombatLogBox/speedControls/speedSlider
@onready var speed_label: Label = $LogPanel/RightSidePanel/PanelContainer/CombatLogBox/speedControls/lblSpeed
@onready var pause_button: Button = $LogPanel/RightSidePanel/PanelContainer/CombatLogBox/speedControls/btnPause

# Combat log
@onready var combat_log: RichTextLabel = $LogPanel/RightSidePanel/PanelContainer/CombatLogBox/txtCombatLog
@onready var turn_label: Label = $LogPanel/RightSidePanel/PanelContainer/CombatLogBox/lblTurn

# Victory Panel
@onready var victory_panel: Panel = $VictoryPanel
@onready var death_panel: Panel = $DeathPanel
@onready var reward_label: Label = $VictoryPanel/PanelContainer/MarginContainer/VBoxContainer/boxReward/panelReward/MarginContainer/HBoxContainer/lblRewardAmt
@onready var txt_history: RichTextLabel = $VictoryPanel/PanelContainer/MarginContainer/VBoxContainer/boxHistory/txtHistory
@onready var txt_history_dead: RichTextLabel =$DeathPanel/PanelContainer/MarginContainer/VBoxContainer/boxHistory/txtHistoryDead

# Animation
@onready var slide_animation: AnimationPlayer = $combatPanelAnim

# Main Game Controller
var main_game: MainGameController 

# State management
var current_state: PanelState = PanelState.HIDDEN
var is_animating: bool = false

var item_proc = preload("res://Scenes/Elements/combat_item_proc.tscn")
var turn_sign = preload("res://Scenes/Elements/combat_turn_sign.tscn")
var status_box = preload("res://Scenes/Elements/status_box.tscn")
var turn_box: CombatTurnSign

# Combat state
var is_visible: bool = false
var current_player_entity
var current_enemy_entity: Enemy
var highlighted_item_slot: ItemSlot = null
var combat_messages_queue: Array[String] = []

# References to inventory slots for highlighting
var inventory_item_slots: Array[ItemSlot] = []
var weapon_slot_ref: ItemSlot = null

# Colors for combat log - TODO: Use GameColors for these.
var color_damage = Color.RED
var color_heal = Color.GREEN
var color_shield = Color.CYAN
var color_status = Color.YELLOW
var color_trigger = Color.MAGENTA

var gamecolors: GameColors


func _ready():
	# Start off-screen
	visible = false
	_set_state(PanelState.HIDDEN)
	connect_combat_signals()

	# Set initial speed
	speed_slider.value =  1.0 #CombatManager.CombatSpeed.NORMAL
	_update_speed_label(CombatManager.CombatSpeed.NORMAL)

func connect_combat_signals():
	# Connect to CombatManager signals
	CombatManager.combat_started.connect(_on_combat_started)
	CombatManager.combat_ended.connect(_on_combat_ended)
	CombatManager.turn_started.connect(_on_turn_started)
	CombatManager.turn_ended.connect(_on_turn_ended)
	
	# Combat event signals
	CombatManager.attack_executed.connect(_on_attack_executed)
	CombatManager.damage_dealt.connect(_on_damage_dealt)
	CombatManager.healing_applied.connect(_on_healing_applied)
	CombatManager.stat_changed.connect(_on_stat_changed)
	CombatManager.status_applied.connect(_on_status_applied)
	CombatManager.status_removed.connect(_on_status_removed)
	CombatManager.status_proc.connect(spawn_status_proc_indicator)

	# Item/ability triggers
	CombatManager.item_rule_triggered.connect(_on_item_rule_triggered)
	CombatManager.enemy_ability_triggered.connect(_on_enemy_ability_triggered)
	
	# Special events
	CombatManager.entity_exposed.connect(_on_entity_exposed)
	CombatManager.entity_wounded.connect(_on_entity_wounded)

func setup_for_combat(enemy_entity, inventory_slots: Array[ItemSlot], weapon_slot: ItemSlot):
	"""Initialize the combat panel with entity data and inventory references"""
	current_player_entity = Player
	inventory_item_slots = inventory_slots
	weapon_slot_ref = weapon_slot
	
	current_enemy_entity = enemy_entity.duplicate()  # Work with a copy
	current_enemy_entity.reset_to_base_values()

	# Setup enemy display
	if current_enemy_entity is Enemy:
		enemy_name_label.text = current_enemy_entity.enemy_name
		enemy_desc_label.text = current_enemy_entity.description
		if current_enemy_entity.sprite:
			enemy_sprite.texture = current_enemy_entity.sprite
			enemy_name_label.modulate = current_enemy_entity.sprite_color
	
	# Initialize enemy stats display
	_update_enemy_stats()
	
	_set_state(PanelState.PRE_COMBAT)

	# Clear combat log
	combat_log.clear()
	combat_log.append_text("[center][b]== COMBAT START ==[/b][/center]\n")
	
	# Reset turn counter
	turn_label.text = "Turn: 0"
	#current_turn_indicator.text = ""

	# Update the RUN button stuff
	var can_run = Player.stats.agility > current_enemy_entity.stats.agility
	btn_run.disabled = !can_run
	if not can_run:
		btn_run.tooltip_text = "Enemy is too fast to escape!"
	
	# lets see.. i don't know
	show_panel()

func show_panel():
	"""Slide the combat panel in from the right"""
	if is_visible:
		return
		
	visible = true
	is_visible = true
	
	slide_animation.play("open_Combat")
	await slide_animation.animation_finished
	combat_ui_ready.emit()

func hide_panel():
	"""Slide the combat panel out to the right"""
	if not is_visible:
		return
	
	is_visible = false
	slide_animation.play("close_combat")
	await slide_animation.animation_finished
	visible = false
	
	box_fight_run.visible = true
	box_combat_log.visible = false

	# Clear highlighted items
	_clear_all_highlights()

func _update_enemy_stats():
	if not current_enemy_entity:
		print("THERE IS NO ENEMY!!!!!!!!!!")
		return
	
	# HP
	enemy_health_stat.update_stat(Enums.Stats.HITPOINTS, current_enemy_entity.stats.hit_points_current, current_enemy_entity.stats.hit_points)

	# Shield stat
	enemy_shield_stat.update_stat(Enums.Stats.SHIELD, current_enemy_entity.stats.shield_current, -1)
	
	# Damage stat
	enemy_damage_stat.update_stat(Enums.Stats.DAMAGE, current_enemy_entity.stats.damage_current, -1)
	
	# Agility stat
	enemy_agility_stat.update_stat(Enums.Stats.AGILITY, current_enemy_entity.stats.agility_current, -1)

func _update_enemy_status_effects():

	for child in enemy_status_box_container.get_children():
		enemy_status_box_container.remove_child(child)
		child.queue_free()

	if current_enemy_entity.status_effects.poison > 0:
		create_new_status_box(Enums.StatusEffects.POISON, current_enemy_entity.status_effects.poison)
	if current_enemy_entity.status_effects.acid > 0:
		create_new_status_box(Enums.StatusEffects.ACID, current_enemy_entity.status_effects.acid)
	if current_enemy_entity.status_effects.thorns > 0:
		create_new_status_box(Enums.StatusEffects.THORNS, current_enemy_entity.status_effects.thorns)
	if current_enemy_entity.status_effects.burn > 0:
		create_new_status_box(Enums.StatusEffects.BURN, current_enemy_entity.status_effects.burn)
	if current_enemy_entity.status_effects.regeneration > 0:
		create_new_status_box(Enums.StatusEffects.REGENERATION, current_enemy_entity.status_effects.regeneration)
	if current_enemy_entity.status_effects.blind > 0:
		create_new_status_box(Enums.StatusEffects.BLIND, current_enemy_entity.status_effects.blind)
	if current_enemy_entity.status_effects.blessing > 0:
		create_new_status_box(Enums.StatusEffects.BLESSING, current_enemy_entity.status_effects.blessing)
	if current_enemy_entity.status_effects.stun > 0:
		create_new_status_box(Enums.StatusEffects.STUN, current_enemy_entity.status_effects.stun)						

func create_new_status_box(_status: Enums.StatusEffects, amount: int):
		var item_container = status_box.instantiate()

		item_container.set_status(_status, amount)
		item_container.custom_minimum_size = Vector2(120, 78)

		enemy_status_box_container.add_child(item_container)

func loop_through_enemy_statuses_for_position(_status: Enums.StatusEffects) -> Vector2:
	var offset: Vector2 = Vector2(45,50)

	if !_status:
		return Vector2(400,200)

	for child in enemy_status_box_container.get_children():
		if child:
			if child.status == _status:
				return child.global_position + offset

	return Vector2(400,200)

func highlight_item_slot(slot_index: int, is_weapon: bool = false):
	"""Highlight a specific inventory slot during combat"""
	_clear_all_highlights()
	
	if is_weapon and weapon_slot_ref:
		highlighted_item_slot = weapon_slot_ref
		weapon_slot_ref.start_combat_highlight()
	elif slot_index >= 0 and slot_index < inventory_item_slots.size():
		highlighted_item_slot = inventory_item_slots[slot_index]
		if highlighted_item_slot:
			highlighted_item_slot.start_combat_highlight()

func _clear_all_highlights():
	"""Clear all inventory highlights"""
	if highlighted_item_slot:
		highlighted_item_slot.stop_combat_highlight()
		highlighted_item_slot = null
	
	# Ensure all slots are unhighlighted
	for slot in inventory_item_slots:
		if slot:
			slot.stop_combat_highlight()
	
	if weapon_slot_ref:
		weapon_slot_ref.stop_combat_highlight()

func add_combat_message(message: String, color: Color = Color.WHITE):
	"""Add a message to the combat log with color"""
	combat_log.push_color(color)
	combat_log.append_text(message + "\n")
	combat_log.pop()
	
	# Auto-scroll to bottom
	combat_log.scroll_to_line(combat_log.get_line_count() - 1)

# Signal handlers
func _on_combat_started(player_entity, enemy_entity):
	print("IS THIS FUNCTION CALL UNNECESSARY????")
	create_timed_message("Battle  Start!")
	#setup_for_combat(enemy_entity, inventory_item_slots, weapon_slot_ref)
	#show_panel()

func _on_combat_ended(winner, loser):
	var winner_name = CombatManager.get_entity_name(winner)
	var loser_name = CombatManager.get_entity_name(loser)
	
	combat_log.append_text("\n[center][b]== COMBAT ENDED ==[/b][/center]\n")
	
	if winner == current_player_entity:
		add_combat_message(winner_name + " WINS!", Color.GREEN)
		var gold_earned = CombatManager.calculate_gold_reward(loser) if loser is Enemy else 0
		if gold_earned > 0:
			add_combat_message("Gained %d gold!" % gold_earned, color_status)
			reward_label.text = str(gold_earned)
			Player.add_gold(gold_earned)
		
		slide_animation.play("enemy_die")
		await slide_animation.animation_finished
	else:
		add_combat_message(loser_name + " has been defeated!", Color.RED)
	
	# Wait a moment before hiding
	Player.status_effects.reset_statuses()

	create_timed_message("Battle  Over!")
	await get_tree().create_timer(2.0).timeout
	_set_state(PanelState.POST_COMBAT)

	#await hide_panel()
	#clear_enemy_status_panel()

	if winner == current_player_entity:
		victory_panel.visible = true
	else:
		death_panel.visible = true

	#combat_completed.emit(winner == current_player_entity)

func clear_enemy_status_panel():
	for child in enemy_status_box_container.get_children():
		enemy_status_box_container.remove_child(child)
		child.queue_free()

func create_timed_message(msg: String) -> CombatTurnSign:

	var box_label = turn_sign.instantiate()
	
	box_label.set_label(msg)		
	add_child(box_label)

	return box_label

func _on_turn_started(entity):
	"""Handle turn start"""
	var entity_name = CombatManager.get_entity_name(entity)
	turn_label.text = "Turn: " + str(CombatManager.turn_number) + " (" + entity_name + "'s turn)"
	add_combat_message("\n--- %s's Turn ---" % entity_name, Color.CYAN)
	
	# turn_box = create_timed_message("Turn: " + str(CombatManager.turn_number) + " (" + entity_name + "'s turn)")

func _on_turn_ended(entity):
	"""Handle turn end"""
	_clear_all_highlights()
	#turn_box.fade_out()

func _on_attack_executed(attacker, target, damage):
	if target == current_enemy_entity:
		slide_animation.play("player_attack")
		await slide_animation.animation_finished
	elif target == current_player_entity:
		slide_animation.play("enemy_attack")
		await slide_animation.animation_finished

func _on_damage_dealt(target, amount, taken_by):
	var target_name = CombatManager.get_entity_name(target)
	add_combat_message("%s takes %d damage!" % [target_name, amount], color_damage)
	
	var combat_item_proc = item_proc.instantiate()
	
	combat_item_proc.set_references()
	combat_item_proc.set_stat_visuals(taken_by)
	combat_item_proc.set_label(amount * -1) # - JDM: multiply negative so damage says minus		

	# Update enemy stats if they were damaged
	if target == current_enemy_entity:
		combat_item_proc.set_info("You hit the Enemy!")
		combat_item_proc.set_item_visuals(Player.inventory.weapon_slot.item_icon, Player.inventory.weapon_slot.item_color)
		add_child(combat_item_proc)

		if taken_by == Enums.Stats.SHIELD || taken_by == Enums.Stats.EXPOSED:
			combat_item_proc.global_position = enemy_shield_stat.global_position + Vector2(45,50)
		else:
			combat_item_proc.global_position = enemy_health_stat.global_position + Vector2(45,50)

		combat_item_proc.run_animation(Enums.Party.ENEMY)

		_update_enemy_stats()
	else:
		combat_item_proc.set_info("The Enemy hits You!")
		combat_item_proc.set_item_visuals(current_enemy_entity.weapon_sprite,current_enemy_entity.sprite_color)
		add_child(combat_item_proc)
		
		if taken_by == Enums.Stats.SHIELD || taken_by == Enums.Stats.EXPOSED:
			combat_item_proc.position = main_game.stat_shield.global_position + Vector2(45, -50)
		else:
			combat_item_proc.position = main_game.stat_health.global_position + Vector2(45, -50)

		combat_item_proc.run_animation(Enums.Party.PLAYER)
		Player.stats.stats_updated.emit()



func _on_healing_applied(target, amount):
	"""Handle healing"""
	var target_name = CombatManager.get_entity_name(target)
	add_combat_message("%s heals %d HP!" % [target_name, amount], color_heal)
	
	# Update enemy stats if they were healed
	if target == current_enemy_entity:
		_update_enemy_stats()

func _on_stat_changed(entity, stat_name: String, old_value: int, new_value: int):
	"""Handle stat changes"""
	if entity == current_enemy_entity:
		_update_enemy_stats()
	else:
		Player.stats.stats_updated.emit()
	
	# Log significant stat changes
	var change = new_value - old_value
	if change != 0:
		var entity_name = CombatManager.get_entity_name(entity)
		var change_text = "+%d" % change if change > 0 else str(change)
		add_combat_message("%s: %s %s (%d → %d)" % [entity_name, stat_name, change_text, old_value, new_value], color_status)

func _on_status_applied(entity, status_name: Enums.StatusEffects, stacks: int):
	"""Handle status effect application"""
	var entity_name = CombatManager.get_entity_name(entity)
	add_combat_message("%s gains %d %s!" % [entity_name, stacks, Enums.get_status_string(status_name)], color_status)
	if entity == Player:
		Player.status_updated.emit(null, 0)
	else:
		_update_enemy_status_effects()

func _on_status_removed(entity, status_name: Enums.StatusEffects):
	"""Handle status effect removal"""
	var entity_name = CombatManager.get_entity_name(entity)
	add_combat_message("%s's %s expired" % [entity_name, Enums.get_status_string(status_name)], Color.GRAY)
	if entity == Player:
		Player.status_updated.emit(null, 0)	

func _on_item_rule_triggered(item: Item, rule: ItemRule, entity):
	# JDM: For multiplayer I will have to have the entity for the attacker always proc the visual cue regardless of
	# ---- which entity is the recipient.

	if entity == current_player_entity || entity == current_enemy_entity:
	# Find which slot this item is in
		# Check weapon slot
		if weapon_slot_ref and weapon_slot_ref.current_item == item:
			spawn_item_proc_indicator(item, rule, entity)
			highlight_item_slot(0, true)
			add_combat_message("⚔ %s: %s" % [item.item_name, rule.get_description()], color_trigger)
		else:
			# Check inventory slots
			for i in range(inventory_item_slots.size()):
				if inventory_item_slots[i] and inventory_item_slots[i].current_item == item:
					spawn_item_proc_indicator(item, rule, entity)
					highlight_item_slot(i, false)
					add_combat_message("📦 [%d] %s: %s" % [i+1, item.item_name, rule.get_description()], color_trigger)
					break

func spawn_item_proc_indicator(item: Item, rule: ItemRule, entity):
	var combat_item_proc = item_proc.instantiate()
	var _pos = Vector2(0,0)
	var offset = Vector2(45, -50)
	
	combat_item_proc.set_references()
	combat_item_proc.set_label(rule.effect_amount)		
	combat_item_proc.set_info(Enums.get_trigger_type_string(rule.trigger_type))
	combat_item_proc.set_item_visuals(item.item_icon, item.item_color)

	if rule.effect_type == Enums.EffectType.MODIFY_STAT:
		combat_item_proc.set_stat_visuals(rule.target_stat)
		if rule.target_stat == Enums.Stats.HITPOINTS:
			_pos = main_game.stat_health.global_position + offset
		if rule.target_stat == Enums.Stats.DAMAGE:
			_pos = main_game.stat_damage.global_position + offset
		if rule.target_stat == Enums.Stats.SHIELD:
			_pos = main_game.stat_shield.global_position + offset
		if rule.target_stat == Enums.Stats.AGILITY:
			_pos = main_game.stat_agility.global_position + offset	
		if rule.target_stat == Enums.Stats.GOLD:
			_pos = main_game.stat_gold.global_position + offset
	elif rule.effect_type == Enums.EffectType.APPLY_STATUS:
		combat_item_proc.set_status_visuals(rule.target_status)
		_pos = main_game.loop_through_player_items_for_position(item)

	add_child(combat_item_proc)
	combat_item_proc.position = _pos

	# Update enemy stats if they were damaged
	if entity == Player:
		combat_item_proc.run_animation(Enums.Party.PLAYER)
	else:
		combat_item_proc.run_animation(Enums.Party.ENEMY)


func spawn_status_proc_indicator(entity, _status: Enums.StatusEffects, _stat: Enums.Stats, value: int):
	var combat_item_proc = item_proc.instantiate()
	
	combat_item_proc.set_references()
	combat_item_proc.set_label(value)	
	combat_item_proc.set_info("Status Effect")	
	combat_item_proc.set_status_as_item_visuals(_status)
	combat_item_proc.set_stat_visuals(_stat)

	add_child(combat_item_proc)

	if entity == current_player_entity:
		combat_item_proc.run_animation(Enums.Party.PLAYER)
		if _stat == Enums.Stats.SHIELD || _stat == Enums.Stats.EXPOSED:
			combat_item_proc.global_position = main_game.stat_shield.global_position + Vector2(45,-50)
		else:
			combat_item_proc.global_position = main_game.stat_health.global_position + Vector2(45,-50)		
	else:
		combat_item_proc.run_animation(Enums.Party.ENEMY)
		if _stat == Enums.Stats.SHIELD || _stat == Enums.Stats.EXPOSED:
			combat_item_proc.global_position = enemy_shield_stat.global_position + Vector2(45,50)
		else:
			combat_item_proc.global_position = enemy_health_stat.global_position + Vector2(45,50)

func _on_enemy_ability_triggered(ability: EnemyAbility, entity):
	"""Handle enemy ability triggers"""
	add_combat_message("🎯 %s uses %s!" % [CombatManager.get_entity_name(entity), ability.ability_name], color_trigger)

func _on_entity_exposed(entity):
	"""Handle exposed event"""
	var entity_name = CombatManager.get_entity_name(entity)
	add_combat_message("⚠ %s is EXPOSED!" % entity_name, Color.ORANGE)

func _on_entity_wounded(entity):
	"""Handle wounded event"""
	var entity_name = CombatManager.get_entity_name(entity)
	add_combat_message("💔 %s is WOUNDED!" % entity_name, Color.ORANGE)

func _update_speed_label(speed: CombatManager.CombatSpeed):
	match speed:
		CombatManager.CombatSpeed.PAUSE:
			speed_label.text = "0x"
			#pause_button.text = "▶ Resume"
		CombatManager.CombatSpeed.NORMAL:
			speed_label.text = "1x"
			#pause_button.text = "⏸ Pause"
		CombatManager.CombatSpeed.FAST:
			speed_label.text = "1.5x"
			#pause_button.text = "⏸ Pause"
		CombatManager.CombatSpeed.VERY_FAST:
			speed_label.text = "2x"
			#pause_button.text = "⏸ Pause"


func _on_speed_slider_value_changed(value: float) -> void:
	"""Handle speed slider change"""
	var speed = int(value) as CombatManager.CombatSpeed
	CombatManager.set_combat_speed(speed)
	_update_speed_label(speed)
	speed_changed.emit(speed)


func _on_btn_pause_pressed() -> void:
	"""Handle pause button"""
	if CombatManager.combat_speed == 0:
		# Unpause - return to normal speed
		speed_slider.value = CombatManager.CombatSpeed.NORMAL
		#ause_button.text = "⏸ Pause"
	else:
		# Pause
		speed_slider.value = CombatManager.CombatSpeed.PAUSE
		speed_changed.emit(0)
		#pause_button.text = "▶ Resume"



func _on_btn_run_pressed() -> void:
	# Emit signal for room event
	player_chose_run.emit()
	
	# Slide out
	await hide_panel()
	
	# Complete without combat
	combat_completed.emit(false)

func _on_btn_fight_pressed() -> void:
	box_fight_run.visible = false
	box_combat_log.visible = true

	# Transition to combat state
	_set_state(PanelState.IN_COMBAT)
	
	# Emit signal for room event
	player_chose_fight.emit()
	
	# Start the actual combat
	CombatManager.start_combat(current_player_entity, current_enemy_entity)

func _set_state(new_state: PanelState):
	current_state = new_state
	


func _on_btn_play_pressed() -> void:
	speed_slider.value = CombatManager.CombatSpeed.NORMAL
	speed_changed.emit(1)


func _on_btn_fast_pressed() -> void:
	speed_slider.value = CombatManager.CombatSpeed.FAST
	speed_changed.emit(2)


func _on_btn_very_fast_pressed() -> void:
	speed_slider.value = CombatManager.CombatSpeed.VERY_FAST
	speed_changed.emit(3)


func _on_btn_continue_pressed() -> void:
	victory_panel.visible = false
	await hide_panel()
	clear_enemy_status_panel()
	combat_completed.emit(true)


func _on_btn_history_pressed() -> void:
	txt_history.visible = !txt_history.visible
	txt_history.text = CombatManager.combat_log
