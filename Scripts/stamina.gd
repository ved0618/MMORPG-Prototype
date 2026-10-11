# Stamina Component
# Stores stamina and handles drain/regen for sprinting
extends Node

signal stamina_changed(current_stamina, max_stamina)
signal stamina_depleted

# Editable in the Inspector
@export var max_stamina: float = 100.0
@export var drain_rate: float = 25.0   # per second while sprinting
@export var regen_rate: float = 15.0   # per second while not sprinting

var current_stamina: float

func _ready() -> void:
	current_stamina = max_stamina

# Called by the player each frame while sprinting
func drain(delta: float) -> void:
	current_stamina = maxf(current_stamina - drain_rate * delta, 0.0)
	emit_signal("stamina_changed", current_stamina, max_stamina)
	if current_stamina <= 0.0:
		emit_signal("stamina_depleted")

# Called by the player each frame while NOT sprinting
func regen(delta: float) -> void:
	if current_stamina < max_stamina:
		current_stamina = minf(current_stamina + regen_rate * delta, max_stamina)
		emit_signal("stamina_changed", current_stamina, max_stamina)

# Spends a flat amount of stamina instantly (e.g. a teleport ability).
# Returns true if the player had enough stamina to pay for it.
func spend(amount: float) -> bool:
	if current_stamina < amount:
		return false
	current_stamina = maxf(current_stamina - amount, 0.0)
	emit_signal("stamina_changed", current_stamina, max_stamina)
	return true
