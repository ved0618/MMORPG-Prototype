extends Node

const IP_ADDRESS: String = "localhost"
const PORT = 5000
const MAX_PLAYERS = 5

var peer: ENetMultiplayerPeer 

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer

func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer
