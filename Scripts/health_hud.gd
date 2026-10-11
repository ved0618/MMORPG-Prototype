# Health HUD
# Shows the health of this local player's character.
# Health itself is replicated from the server, so poll the replicated
# property as well as listening for local health_changed signals.
extends CanvasLayer

@onready var bar: ProgressBar = $Control/HealthBar
@onready var player: Node = get_parent()
@onready var health: Node = player.get_node_or_null("Health(Node)")

func _ready() -> void:
	visible = player.is_multiplayer_authority()
	if health == null:
		push_warning("HealthHUD: Player has no Health(Node) child.")
		return

	if health.has_signal("health_changed"):
		var callback := Callable(self, "_on_health_changed")
		if not health.health_changed.is_connected(callback):
			health.health_changed.connect(callback)

	_sync_bar()

func _process(_delta: float) -> void:
	if visible and is_instance_valid(health):
		_sync_bar()

func _on_health_changed(_current: int, _max_val: int) -> void:
	_sync_bar()

func _sync_bar() -> void:
	if not is_instance_valid(health) or bar == null:
		return
	bar.max_value = maxf(1.0, float(health.max_health))
	bar.value = clampf(float(health.current_health), 0.0, bar.max_value)
