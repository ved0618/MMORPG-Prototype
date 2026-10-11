# Health Component
extends Node

signal health_changed(current_health, max_health)
signal died

@export var max_health: int = 10
var current_health: int = 10


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> void:
	# Only the server is allowed to change authoritative health in multiplayer.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if amount <= 0 or current_health <= 0:
		return

	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if multiplayer.has_multiplayer_peer():
		_rpc_sync_health.rpc(current_health, max_health)

	if current_health <= 0:
		died.emit()


func increase_max_health(percent: float, refill: bool = true) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var old_max: int = max_health
	max_health = maxi(old_max + 1, int(round(float(old_max) * (1.0 + percent))))

	if refill:
		current_health = max_health
	else:
		var missing: int = old_max - current_health
		current_health = maxi(0, max_health - missing)

	health_changed.emit(current_health, max_health)
	if multiplayer.has_multiplayer_peer():
		_rpc_sync_health.rpc(current_health, max_health)


@rpc("any_peer", "call_local", "reliable")
func _rpc_sync_health(new_current: int, new_max: int) -> void:
	# Only accept network health updates from the server (peer 1).
	# The local call on the server is ignored because server health was
	# already updated by take_damage().
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != 1:
		return

	var previous_health: int = current_health
	max_health = maxi(1, new_max)
	current_health = clampi(new_current, 0, max_health)
	health_changed.emit(current_health, max_health)

	# Emit death only on the transition from alive to dead, not on every
	# replicated zero-health update.
	if previous_health > 0 and current_health == 0:
		died.emit()
