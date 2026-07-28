extends Node2D
@onready var sprite = $AnimatedSprite2D

const OFFSET_UP = Vector2(0, -12)
const OFFSET_DOWN = Vector2(0, 12)
const OFFSET_LEFT = Vector2(-12, 0)
const OFFSET_RIGHT = Vector2(12, 0)

func update_facing(direction: String):
	match direction:
		"up":
			position = OFFSET_UP
		
		"down":
			position = OFFSET_DOWN
		
		"left":
			position = OFFSET_LEFT
		
		"right":
			position = OFFSET_RIGHT
		

func attack(direction: String) -> void:
	
	print("Weapon attacked toward:", direction)
	#sprite.play("attack")
