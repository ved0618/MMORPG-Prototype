# Spawner
# Finite wave spawner. Each map starts one wave and never respawns monsters
# after they die. Map.gd detects when all spawners have been cleared.
extends Node2D

@export var monster_scene: PackedScene
@export var max_alive: int = 2
@export var respawn_delay: float = 0.0
@export var spawn_radius: float = 42.0

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var _spawned: Array[Node] = []
var _wave_active := false
var _wave_started := false

signal wave_cleared


func _ready() -> void:
	spawner.spawn_function = _spawn_monster
	if monster_scene == null:
		push_warning("Spawner '%s' has no monster_scene assigned." % name)


func start_wave() -> void:
	if _wave_started:
		return
	# Do not start a network wave after the session has been closed.
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return

	_wave_started = true
	_wave_active = true
	if monster_scene == null or max_alive <= 0:
		_wave_active = false
		wave_cleared.emit()
		return

	for i in range(max_alive):
		var offset := Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * spawn_radius
		spawner.spawn({"offset": offset})


func _spawn_monster(data: Dictionary) -> Node:
	var monster := monster_scene.instantiate() as Node2D
	monster.position = data["offset"]
	monster.tree_exiting.connect(_on_monster_leaving.bind(monster))
	_spawned.append(monster)
	return monster


func _on_monster_leaving(monster: Node) -> void:
	_spawned.erase(monster)

	# Scene teardown can fire tree_exiting after the multiplayer peer is
	# disconnected. Never try to process wave completion during shutdown.
	if not is_inside_tree() or not multiplayer.has_multiplayer_peer():
		return
	if not multiplayer.is_server() or not _wave_active:
		return

	if _spawned.is_empty():
		_wave_active = false
		wave_cleared.emit()


func is_wave_active() -> bool:
	return _wave_active
