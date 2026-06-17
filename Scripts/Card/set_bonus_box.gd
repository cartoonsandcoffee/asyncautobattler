extends PanelContainer

@onready var bonus_label: Label 
@onready var items_grid: GridContainer
@onready var anim_player: AnimationPlayer

var set_piece = preload("res://Scenes/Card/set_bonus_piece.tscn")
var _refs_set: bool = false

func set_references():
	if _refs_set:
		return
	_refs_set = true	

	bonus_label = $mainMargin/VBoxContainer/lblBonus
	items_grid = $mainMargin/VBoxContainer/itemsGrid
	anim_player = $AnimationPlayer

func setup(keyword: String, color: Color):
	set_references()
	bonus_label.text = keyword.capitalize() + ":"
	bonus_label.modulate = color

func show_def():
	anim_player.play("tooltip_show")

func set_min_width(min_width: float = 0.0):
	custom_minimum_size.x = min_width

func set_ingredients(_set_bonus: SetBonus):
	for child in items_grid.get_children():
		items_grid.remove_child(child)
		child.queue_free()
	
	for item in _set_bonus.required_items:
		var piece = set_piece.instantiate()
		#piece.custom_minimum_size = Vector2(200, 200)
		items_grid.add_child(piece)
		piece.setup(item)
