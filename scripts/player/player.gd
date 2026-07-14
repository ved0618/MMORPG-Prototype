class_name Player
extends CharacterBody2D

var cardinal_direction : Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed : float = 100.0
var state : String = "idle"
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine : PlayerStateMachine = $StateMachine

func _ready() -> void:
	state_machine.Initialize(self)
	
func _process(delta: float) -> void:
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	pass
	
func _physics_process(delta: float) -> void:
	move_and_slide()
	pass

func SetDirection() -> bool:
	if direction == Vector2.ZERO:
		return false

	var new_dir := cardinal_direction

	if abs(direction.x) > abs(direction.y):
		new_dir = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		new_dir = Vector2.DOWN if direction.y > 0 else Vector2.UP

	if new_dir == cardinal_direction:
		return false

	cardinal_direction = new_dir
	return true
	

func UpdateAnimation( state: String) -> void:
	if cardinal_direction == Vector2.LEFT:
		animated_sprite.flip_h = true
		animated_sprite.play(state + "_side")
	elif cardinal_direction == Vector2.RIGHT:
		animated_sprite.flip_h = false
		animated_sprite.play(state + "_side")
	else:
		animated_sprite.flip_h = false
		animated_sprite.play(state + "_" + AnimeDirection())
	
func AnimeDirection() -> String:	
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"
	
	
