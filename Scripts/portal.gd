# Portal
# An Area2D placed at a map edge. When a player walks into it,
# the MapManager loads the destination map and teleports the player there.
extends Area2D

## Which map this portal leads to.
@export var destination_map: String = ""

## Which edge of the destination map the player arrives at.
## "top", "bottom", "left", or "right".
@export var entry_direction: String = "top"

## Emitted with (destination_map, entry_direction, player_body)
signal portal_entered(destination_map: String, entry_direction: String, player: Node2D)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Only trigger for players (CharacterBody2D in "players" group)
	if body.is_in_group("players") and body.has_method("set_multiplayer_authority"):
		# Only the server processes transitions (or single-player)
		if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
			print("Portal: player ", body.name, " entered portal to ", destination_map, " via ", entry_direction)
			portal_entered.emit(destination_map, entry_direction, body)
