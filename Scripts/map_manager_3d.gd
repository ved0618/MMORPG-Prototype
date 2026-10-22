# MapManager 3D (2.5D / HD-2D)
# Sequential wave-based 3D map progression.
# The server controls the current level, wave completion, countdown delay,
# and teleports all connected players in 3D space to the next level.
extends Node3D

const MapDataScript := preload("res://Scripts/map_data.gd")

const LEVEL_DELAY: float = 5.0

var MAP_DATA: Dictionary = MapDataScript.MAPS
var loaded_maps: Dictionary = {}
var _pending_adds: Array = []
var _pending_wave_maps: Dictionary = {}
var _map_ready_peers: Dictionary = {}

var current_map_id: String = "001"
var _level_transition_started: bool = false
var _level_transition_timer: Timer

signal map_transitioned(from_map: String, to_map: String)
signal level_cleared(map_id: String, seconds_until_next_level: float)
signal level_countdown(seconds_remaining: int)

@onready var maps_container: Node3D = self


func _ready() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_level_transition_timer = Timer.new()
	_level_transition_timer.one_shot = true
	add_child(_level_transition_timer)
	_level_transition_timer.timeout.connect(_on_level_delay_finished)

	_load_map(current_map_id)
	_process_pending_adds()


func _on_peer_disconnected(peer_id: int) -> void:
	for map_id in _map_ready_peers.keys():
		var readiness: Dictionary = _map_ready_peers[map_id]
		readiness.erase(peer_id)
		_map_ready_peers[map_id] = readiness
		_try_start_wave(map_id)


func _process(_delta: float) -> void:
	_process_pending_adds()


func _process_pending_adds() -> void:
	if _pending_adds.is_empty():
		return

	var batch := _pending_adds.duplicate()
	_pending_adds.clear()

	for entry in batch:
		var map_id: String = entry["map_id"]
		var map_node: Node3D = entry["map_node"]
		maps_container.add_child(map_node)
		loaded_maps[map_id] = map_node

		if map_node.has_signal("wave_cleared"):
			map_node.wave_cleared.connect(_on_wave_cleared.bind(map_id))

		print("MapManager3D: loaded level ", map_id)

		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			_map_ready_peers[map_id] = {}
			for peer_id in multiplayer.get_peers():
				_map_ready_peers[map_id][peer_id] = false
			_rpc_load_map.rpc(map_id)

		if multiplayer.is_server() and map_node.has_method("start_wave"):
			if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
				_pending_wave_maps[map_id] = map_node
				_try_start_wave(map_id)
			else:
				map_node.start_wave()
		elif multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			_rpc_client_map_ready.rpc_id(1, map_id)


func _load_map(map_id: String) -> void:
	if loaded_maps.has(map_id) or _is_pending(map_id):
		return
	if not MAP_DATA.has(map_id):
		push_warning("MapManager3D: unknown map_id '%s'" % map_id)
		return

	var path := "res://Scenes/maps_3d/map_%s.tscn" % map_id
	var packed: PackedScene = load(path)
	if packed == null:
		push_warning("MapManager3D: missing scene for map '%s'" % map_id)
		return

	var map_node := packed.instantiate() as Node3D
	# In 3D, all maps are centered at origin since only 1 level is active at a time
	map_node.position = Vector3.ZERO
	_pending_adds.append({"map_id": map_id, "map_node": map_node})


func _is_pending(map_id: String) -> bool:
	for entry in _pending_adds:
		if entry["map_id"] == map_id:
			return true
	return false


func _unload_map(map_id: String) -> void:
	if not loaded_maps.has(map_id) or map_id == current_map_id:
		return

	var map_node = loaded_maps[map_id]
	if map_node and is_instance_valid(map_node):
		map_node.queue_free()
	loaded_maps.erase(map_id)

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_rpc_unload_map.rpc(map_id)


func _try_start_wave(map_id: String) -> void:
	if not _pending_wave_maps.has(map_id):
		return
	var readiness: Dictionary = _map_ready_peers.get(map_id, {})
	for peer_id in readiness:
		if not readiness[peer_id]:
			return
	var map_node: Node3D = _pending_wave_maps[map_id]
	_pending_wave_maps.erase(map_id)
	if is_instance_valid(map_node) and map_node.is_inside_tree():
		map_node.start_wave()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_map_ready(map_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _map_ready_peers.has(map_id) and _map_ready_peers[map_id].has(peer_id):
		_map_ready_peers[map_id][peer_id] = true
		_try_start_wave(map_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_load_map(map_id: String) -> void:
	_load_map(map_id)
	print("MapManager3D: client received map load for level ", map_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_unload_map(map_id: String) -> void:
	if loaded_maps.has(map_id):
		var map_node = loaded_maps[map_id]
		if map_node and is_instance_valid(map_node):
			map_node.queue_free()
		loaded_maps.erase(map_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_transition(from_map: String, to_map: String) -> void:
	current_map_id = to_map
	map_transitioned.emit(from_map, to_map)


func _on_wave_cleared(map_id: String) -> void:
	if not multiplayer.is_server():
		return
	if map_id != current_map_id or _level_transition_started:
		return

	_level_transition_started = true
	_level_transition_timer.start(LEVEL_DELAY)
	level_cleared.emit(map_id, LEVEL_DELAY)
	print("LEVEL ", map_id, " CLEARED. Next level in ", LEVEL_DELAY, " seconds.")
	_start_countdown()


func _start_countdown() -> void:
	var countdown := get_tree().create_timer(1.0)
	countdown.timeout.connect(_countdown_tick.bind(LEVEL_DELAY))


func _countdown_tick(seconds_left: float) -> void:
	if not _level_transition_started:
		return
	var remaining := maxi(0, int(ceil(seconds_left)))
	level_countdown.emit(remaining)
	if remaining > 0:
		var next_tick := get_tree().create_timer(1.0)
		next_tick.timeout.connect(_countdown_tick.bind(seconds_left - 1.0))


func _on_level_delay_finished() -> void:
	if not multiplayer.is_server():
		return

	var next_map := _get_next_map_id(current_map_id)
	if next_map == "":
		_level_transition_started = false
		print("All levels cleared. Victory!")
		return

	var from_map := current_map_id
	current_map_id = next_map
	_load_map(next_map)

	for _frame in range(4):
		await get_tree().process_frame

	var next_node = loaded_maps.get(next_map)
	if next_node == null:
		push_error("MapManager3D: failed to load next level %s" % next_map)
		_level_transition_started = false
		return

	# Teleport all players to next spawn position
	var players_node := get_parent().get_node_or_null("Players")
	if players_node:
		var spawn_pos: Vector3 = next_node.get_spawn_position("center")
		for player in players_node.get_children():
			if player is CharacterBody3D:
				player.global_position = spawn_pos
				player.velocity = Vector3.ZERO
				if player.has_method("_rpc_force_teleport") and multiplayer.has_multiplayer_peer():
					player._rpc_force_teleport.rpc(spawn_pos)

	# Clean up previous level
	for old_id in loaded_maps.keys().duplicate():
		if old_id != next_map:
			_unload_map(old_id)

	_level_transition_started = false
	map_transitioned.emit(from_map, next_map)
	if multiplayer.has_multiplayer_peer():
		_rpc_transition.rpc(from_map, next_map)


func _get_next_map_id(map_id: String) -> String:
	var number := int(map_id)
	var next_number := number + 1
	if next_number > MAP_DATA.size():
		return ""
	var candidate := "%03d" % next_number
	return candidate if MAP_DATA.has(candidate) else ""


func get_current_map() -> Node3D:
	return loaded_maps.get(current_map_id)


func get_spawn_position(map_id: String = "") -> Vector3:
	if map_id == "":
		map_id = current_map_id
	var map_node = loaded_maps.get(map_id)
	if map_node:
		return map_node.get_spawn_position("center")
	return Vector3.ZERO
