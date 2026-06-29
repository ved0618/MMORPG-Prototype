class_name State_Idle
extends State
@onready var walk: State = $"../walk"

#What happens when the player enters this state?
func Enter() -> void:
	player.UpdateAnimation("idle")
	pass
	
#What happens when the player exits this state?
func Exit() -> void:
	pass
	
#What happens during the _process update in this state? 
func Process( _delta: float ) -> State:
	if player.direction != Vector2.ZERO:
		return walk
	player.velocity = Vector2.ZERO
	return null

#what happens during the _physics process update in this state?
func Physics( _delta: float ) -> State:
	return null
	
#What happens with input event in this state?
func HandleInput( _event: InputEvent ) -> State:
	return null
