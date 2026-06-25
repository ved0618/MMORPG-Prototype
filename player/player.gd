class_name Player
extends CharacterBody2D

var cardinal_direction : Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed : float = 100.0

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	pass
	
func _physics_process(delta: float) -> void:
	pass

func SetDirection() -> bool:
	
	return true
	
func SetState() -> bool:
	
	return true

func UpdateAnimation() -> void:
	AnimationPlayer.play(state + "_" + AnimeDirection())
	pass
	
func AnimeDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	if cardinal_direction == Vector2.UP:
		return "up"
	if cardinal_direction == Vector2.LEFT:
		return "left"
	else cardinal_direction == Vector2.RIGHT:
