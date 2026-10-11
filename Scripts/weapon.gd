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
	if multiplayer.is_server():
		hitbox.enable_hitbox()
	else:
		hitbox.enable_hitbox()
		# Send our current facing direction so the server places the hitbox correctly
		var player = get_parent()
		var dir := "down"
		if player and player.has_method("handle_input"):
			dir = player.facing_direction
		rpc_id(1, "_server_enable_hitbox", dir)


func disable_hitbox():
	if multiplayer.is_server():
		hitbox.disable_hitbox()
	else:
		hitbox.disable_hitbox()
		rpc_id(1, "_server_disable_hitbox")


@rpc("any_peer", "reliable")
func _server_enable_hitbox(facing: String = "down") -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()

	if sender_id != get_parent().get_multiplayer_authority():
		return

	# Update the weapon offset to match the client's facing direction
	update_facing(facing)
	hitbox.enable_hitbox()


@rpc("any_peer", "reliable")
func _server_disable_hitbox() -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()

	if sender_id != get_parent().get_multiplayer_authority():
		return

	hitbox.disable_hitbox()
