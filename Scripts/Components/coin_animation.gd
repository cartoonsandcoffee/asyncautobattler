extends Control
class_name CoinAnim

@onready var anim_coin: AnimationPlayer = $animCoin

func play_coin_anim() -> void:
	anim_coin.play("coin_spin")