# status_effects.gd
class_name StatusEffects
extends Resource

## Manages all status effects for an entity (player/enemy/boss)
## Each status effect has a stack count that decreases over time

signal overheal_triggered(amount: int)
signal status_updated(_status: Enums.StatusEffects, amount: int)

# Status effect stacks
@export var poison: int = 0
@export var thorns: int = 0
@export var acid: int = 0
@export var regeneration: int = 0
@export var stun: int = 0
@export var burn: int = 0
@export var blessing: int = 0
@export var blind: int = 0


func _init():
	pass

func reset_statuses():
	poison = 0
	thorns = 0
	acid = 0
	regeneration = 0
	stun = 0
	burn = 0
	blessing = 0
	blind = 0
	status_updated.emit(null, 0)

func decrement_status(_status: Enums.StatusEffects, amount: int = 1):
	match _status:
		Enums.StatusEffects.POISON:
			if poison > 0:
				poison -= amount

			if poison < 0:
				poison = 0
		Enums.StatusEffects.THORNS:
			if thorns > 0:
				thorns -= amount

			if thorns < 0:
				thorns = 0			
		Enums.StatusEffects.ACID:
			if acid > 0:
				acid -= amount

			if acid < 0:
				acid = 0					
		Enums.StatusEffects.REGENERATION:
			if regeneration > 0:
				regeneration -= amount

			if regeneration < 0:
				regeneration = 0				
		Enums.StatusEffects.STUN:
			if stun > 0:
				stun -= amount

			if stun < 0:
				stun = 0			
		Enums.StatusEffects.BURN:
			if burn > 0:
				burn -= amount

			if burn < 0:
				burn = 0			
		Enums.StatusEffects.BLESSING:
			if blessing > 0:
				blessing -= amount

			if blessing < 0:
				blessing = 0			
		Enums.StatusEffects.BLIND:
			if blind > 0:
				blind -= amount

			if blind < 0:
				blind = 0				
	status_updated.emit(_status, amount * -1)

func remove_status(_status: Enums.StatusEffects):
	match _status:
		Enums.StatusEffects.POISON:
			poison = 0
		Enums.StatusEffects.THORNS:
			thorns = 0
		Enums.StatusEffects.ACID:
			acid = 0
		Enums.StatusEffects.REGENERATION:
			regeneration = 0
		Enums.StatusEffects.STUN:
			stun = 0
		Enums.StatusEffects.BURN:
			burn = 0
		Enums.StatusEffects.BLESSING:
			blessing = 0
		Enums.StatusEffects.BLIND:
			blind = 0
	status_updated.emit(_status, 0)	

func increment_status(_status: Enums.StatusEffects, amount: int = 1):
	match _status:
		Enums.StatusEffects.POISON:
			poison += amount
		Enums.StatusEffects.THORNS:
			thorns += amount
		Enums.StatusEffects.ACID:
			acid += amount
		Enums.StatusEffects.REGENERATION:
			regeneration += amount
		Enums.StatusEffects.STUN:
			stun += amount
		Enums.StatusEffects.BURN:
			burn += amount
		Enums.StatusEffects.BLESSING:
			blessing += amount
		Enums.StatusEffects.BLIND:
			blind += amount
	status_updated.emit(_status, amount)
