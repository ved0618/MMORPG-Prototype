#Weapon
#Controls weapon position and attack properties
extends Node2D
#@onready var sprite = $"../AnimatedSprite2D"
@onready var hitbox = $"Hitbox(Area2D)"

# Weapon stats stay here instead of Plyaer,
# allowing different weapons to have unique damage
@export var damage : int = 10

const OFFSET_UP = Vector2(0, -12)
const OFFSET_DOWN = Vector2(0, 12)
const OFFSET_LEFT = Vector2(-12, 0)
const OFFSET_RIGHT = Vector2(12, 0)

# Keeps the weapon positioned in front of the player
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
		

#func attack(direction: String) -> void:
	#
	#print("Weapon attacked toward:", direction)
	#sprite.play("attack")

# Called by AnimationPlayer during attack frames
func enable_hitbox():
	hitbox.enable_hitbox()

func disable_hitbox():
	hitbox.disable_hitbox()
