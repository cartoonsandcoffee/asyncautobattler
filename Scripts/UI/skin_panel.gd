extends Control

signal refresh_skin()

@onready var lbl_feedback: Label = $PanelContainer/VBoxContainer/lblSkins
@onready var skin_grid: GridContainer = $PanelContainer/VBoxContainer/ScrollContainer/skinGrid
@onready var skin_card: SkinCard = $SkinCard

const SKIN_BUTTON = preload("res://Scenes/Elements/skin_button.tscn")

func _ready() -> void:
	print("[SkinPanel] Loading skin panel.")
	_refresh()
	SkinManager.skin_selected.connect(_on_skin_selected)
	SkinManager.skin_unlocked.connect(_on_skin_unlocked)

func _refresh() -> void:
	lbl_feedback.text = "Skins"
	_build_skin_cards()

func _build_skin_cards() -> void:
	# Clear existing cards
	for child in skin_grid.get_children():
		child.queue_free()
	
	for skin in SkinManager.all_skins:
		var card = SKIN_BUTTON.instantiate()
		skin_grid.add_child(card)
		card.setup(skin)
		card.buy_pressed.connect(_on_buy_pressed.bind(skin))
		card.select_pressed.connect(_on_select_pressed.bind(skin))
		card.hover_on.connect(_show_hover_card.bind(skin))
		card.hover_out.connect(_hide_hover_card)
	
func _hide_hover_card():
	skin_card.visible = false

func _show_hover_card(skin: SkinData):
	skin_card.setup(skin)
	skin_card.visible = true

func _on_buy_pressed(skin: SkinData) -> void:
	if Player.ears_balance < skin.cost:
		_show_feedback("Not enough ears! Need %d." % skin.cost, false)
		return
	
	var player_id = Player.load_or_generate_uuid()
	_attempt_purchase(player_id, skin)

func _attempt_purchase(player_id: String, skin: SkinData) -> void:
	lbl_feedback.text = "Purchasing..."
	var success = await SupabaseManager.spend_ears_simple(player_id, skin.cost, "Skin purchase: %s" % skin.display_name)
	
	if success:
		# Sync local ears from Supabase
		var profile = await SupabaseManager.get_player_profile(player_id)
		if not profile.is_empty():
			Player.update_ears(profile.ears_balance)
		
		SkinManager.unlock_skin(skin.skin_id)
		_refresh()
		_show_feedback("Unlocked %s!" % skin.display_name, true)
		AudioManager.play_ui_sound("button_click")
		_refresh()
	else:
		_show_feedback("Purchase failed. Try again.", false)

func _on_select_pressed(skin: SkinData) -> void:
	SkinManager.select_skin(skin.skin_id)
	_refresh_card_states()
	AudioManager.play_ui_sound("button_click")
	refresh_skin.emit()
	
func _refresh_card_states() -> void:
	for card in skin_grid.get_children():
		if card.has_method("refresh_state"):
			card.refresh_state()

func _show_feedback(msg: String, success: bool) -> void:
	lbl_feedback.text = msg
	lbl_feedback.modulate = Color.GREEN if success else Color.RED

func _on_skin_selected(_skin_id: int) -> void:
	if visible:
		_refresh_card_states()

func _on_skin_unlocked(_skin_id: int) -> void:
	pass  # _refresh() already called in _on_buy_pressed
