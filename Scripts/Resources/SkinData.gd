class_name SkinData
extends Resource

@export var skin_id: int = 0
@export var display_name: String = "Default"
@export var cost: int = 0  # 0 = free/default
@export var sprite: Texture2D = null
@export var skin_icon: Texture2D = null
@export var player_pov_pic: Texture2D = null
@export var is_default: bool = false
@export var is_unlocked: bool = false
@export var is_hidden: bool = false  ## - JDM: Use this for hiding Path-specific default skins
