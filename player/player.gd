class_name Player
extends CharacterBody2D

var cardinal_direction : Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed : float = 100.0
var state : String = "idle"
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	
	velocity = direction * move_speed
	UpdateAnimation()
	
	pass
	
func _physics_process(delta: float) -> void:
	move_and_slide()
	pass

func SetDirection() -> bool:
	
	return true
	
func SetState() -> bool:
	
	return true

func UpdateAnimation() -> void:
	animated_sprite.play(state + "_" + AnimeDirection())
	pass	
	
func AnimeDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"
	
