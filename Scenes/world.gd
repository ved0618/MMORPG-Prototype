extends Node2D

const PLAYER = preload("res://Scenes/player.tscn")
@onready var players = $Players
@onready var spawn_points = $SpawnPoints.get_children()
var used_spawns = {}

func _ready():
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)

	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id())

func _peer_connected(id):
	print(id, " joined")
	if multiplayer.is_server():
		_spawn_player(id)

func _peer_disconnected(id):
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()
	used_spawns.erase(id)

func _spawn_player(id):
	if players.has_node(str(id)):
		return
	var player = PLAYER.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)

	var spawn_index = used_spawns.size() % spawn_points.size()
	player.global_position = spawn_points[spawn_index].global_position
	used_spawns[id] = spawn_index

	players.add_child(player)  # MultiplayerSpawner sees this and auto-replicates to everyone, including late joiners
