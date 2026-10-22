# Weapon 3D
# Controls weapon position and attack properties in 2.5D/3D space
extends Node3D

@onready var hitbox: Area3D = $"Hitbox(Area3D)"

@export var damage: int = 10

const OFFSET_UP := Vector3(0.0, 0.6, -1.1)
const OFFSET_DOWN := Vector3(0.0, 0.6, 1.1)
const OFFSET_LEFT := Vector3(-1.1, 0.6, 0.0)
const OFFSET_RIGHT := Vector3(1.1, 0.6, 0.0)


func update_facing(direction: String) -> void:
	match direction:
		"up":
			position = OFFSET_UP
		"down":
			position = OFFSET_DOWN
		"left":
			position = OFFSET_LEFT
		"right":
			position = OFFSET_RIGHT


func enable_hitbox() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		hitbox.enable_hitbox()
	else:
		hitbox.enable_hitbox()
		var player = get_parent()
		var dir := "down"
		if player and "facing_direction" in player:
			dir = player.facing_direction
		if multiplayer.has_multiplayer_peer():
			rpc_id(1, "_server_enable_hitbox", dir)


func disable_hitbox() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		hitbox.disable_hitbox()
	else:
		hitbox.disable_hitbox()
		if multiplayer.has_multiplayer_peer():
			rpc_id(1, "_server_disable_hitbox")


@rpc("any_peer", "reliable")
func _server_enable_hitbox(facing: String = "down") -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != get_parent().get_multiplayer_authority():
		return
	update_facing(facing)
	hitbox.enable_hitbox()


@rpc("any_peer", "reliable")
func _server_disable_hitbox() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != get_parent().get_multiplayer_authority():
		return
	hitbox.disable_hitbox()
