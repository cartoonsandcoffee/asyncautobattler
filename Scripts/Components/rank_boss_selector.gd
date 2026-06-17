extends Control

signal button_clicked()
signal button_entered()
signal button_exited()

@onready var pic_icon: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/picContainer/picIcon
@onready var lbl_rank: Label = $PanelContainer/MarginContainer/HBoxContainer/boxInfo/boxRank/lblRank
@onready var lbl_name: Label = $PanelContainer/MarginContainer/HBoxContainer/boxInfo/lblName
@onready var txt_desc: RichTextLabel = $PanelContainer/MarginContainer/HBoxContainer/boxInfo/boxMoreInfo/txtInfo

@onready var btn_boss: Button = $PanelContainer/MarginContainer/btnBoss
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	btn_boss.pressed.connect(func(): button_clicked.emit())
	btn_boss.mouse_entered.connect(on_mouse_entered)
	btn_boss.mouse_exited.connect(on_mouse_exit)

func setup(boss_data: Dictionary, rank: int, is_current: bool = false) -> void:
	lbl_rank.text = " Champion Rank " if rank == 6 else " Rank %d " % rank

	if boss_data.is_empty():
		var is_defeated = rank < DungeonManager.current_rank
		lbl_name.text = "DEFEATED" if is_defeated else "???"
		txt_desc.text = "[color=gray]%s[/color]" % ("Vanquished." if is_defeated else "Lurking in the shadows...")
		modulate = Color(0.45, 0.45, 0.45, 1.0)
		btn_boss.disabled = true
		return

	lbl_name.text = boss_data.get("username", "Unknown")

	var skin_id: int = boss_data.get("skin_id", 0)
	var boss_sprite: Texture2D = SkinManager.get_skin_preview(skin_id)
	if boss_sprite != null:
		pic_icon.texture = boss_sprite

	var player_won: bool = boss_data.get("player_won", true)
	var status := "Glorious" if player_won else "Vengeful"
	var status_color := "gold" if player_won else "tomato"
	var days := _get_days_since(boss_data.get("created_at", ""))
	var times_faced: int = boss_data.get("times_faced", 0)

	txt_desc.text = "[color=%s][b]%s[/b][/color]  ·  reigning [color=white][b]%d[/b][/color] days  ·  faced [color=white][b]%d[/b][/color] others" % [
		status_color, status, days, times_faced
	]

	btn_boss.disabled = not is_current
	modulate = Color(1, 1, 1, 1) if is_current else Color(0.75, 0.75, 0.75, 1)

func _get_days_since(created_at: String) -> int:
	if created_at.is_empty():
		return 0
	var clean = created_at.split("+")[0].rstrip("Z")
	var unix_created = Time.get_unix_time_from_datetime_string(clean)
	return max(0, int((Time.get_unix_time_from_system() - unix_created) / 86400.0))

## ------------------------------------------------
## Buttons
## ------------------------------------------------

func on_mouse_entered():
	CursorManager.set_interact_cursor()
	anim.play("hover_on")
	#button_entered.emit()

func on_mouse_exit():
	CursorManager.reset_cursor()
	anim.play("hover_off")
	#button_exited.emit()