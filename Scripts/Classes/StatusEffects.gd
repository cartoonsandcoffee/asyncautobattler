# status_effects.gd
class_name StatusEffects
extends Resource

## Manages all status effects for an entity (player/enemy/boss)
## Each status effect has a stack count that decreases over time

signal status_applied(status_name: String, amount: int)
signal status_removed(status_name: String)
signal overheal_triggered(amount: int)

# Status effect stacks
@export var poison: int = 0
@export var thorns: int = 0
@export var acid: int = 0
@export var regeneration: int = 0
@export var stun: int = 0
@export var burn: int = 0

func _init():
	pass

