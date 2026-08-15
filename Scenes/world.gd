extends Node2D

const PLAYER_SCENE := preload("res://Scenes/player.tscn")

@onready var players: Node = $Players
@onready var player_spawner: MultiplayerSpawner = $Players/MultiplayerSpawner
@onready var spawn_points: Array[Node] = $SpawnPoints.get_children()

var used_spawns: Dictionary = {}


func _ready() -> void:
	print("=== WORLD READY ===")
	print("Is Server: ", multiplayer.is_server())
	print("My Peer ID: ", multiplayer.get_unique_id())
	print("===================")

	player_spawner.spawn_function = _spawn_custom_player

	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)

	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id())
	else:
		print("Client world ready, waiting for spawn from server")

	print("World ready complete, is_server: ", multiplayer.is_server())


func _peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)

	if multiplayer.is_server():
		_spawn_player(peer_id)


func _peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)

	if players.has_node(str(peer_id)):
		players.get_node(str(peer_id)).queue_free()

	used_spawns.erase(peer_id)


func _spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if players.has_node(str(peer_id)):
		print("Player already exists: ", peer_id)
		return

	var spawn_index := used_spawns.size() % spawn_points.size()
	used_spawns[peer_id] = spawn_index

	var spawn_data := {
		"peer_id": peer_id,
		"position": spawn_points[spawn_index].global_position
	}

	print("Spawning player with peer ID: ", peer_id)
	player_spawner.spawn(spawn_data)


func _spawn_custom_player(data: Dictionary) -> Node:
	var peer_id: int = int(data["peer_id"])
	var spawn_position: Vector2 = data["position"]

	var player := PLAYER_SCENE.instantiate()

	player.name = str(peer_id)
	player.global_position = spawn_position

	# This runs on every peer, including the client.
	# Therefore every peer receives the same authority.
	player.set_multiplayer_authority(peer_id)

	print(
		"Created player ",
		peer_id,
		" with authority ",
		player.get_multiplayer_authority(),
		" on peer ",
		multiplayer.get_unique_id()
	)

	return player
