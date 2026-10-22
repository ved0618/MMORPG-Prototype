# Hitbox 3D
# Detects hurtboxes and deals damage
class_name Hitbox3D
extends Area3D

@onready var weapon = get_parent()

func get_damage() -> int:
	if weapon and "damage" in weapon:
		return weapon.damage
	return 10


func _ready() -> void:
	collision_layer = 8   # Layer 4 (Hitboxes)
	collision_mask = 16   # Layer 5 (Hurtboxes)
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


func enable_hitbox() -> void:
	monitoring = true
	monitorable = true


func disable_hitbox() -> void:
	monitoring = false
	monitorable = false


func _on_area_entered(area: Area3D) -> void:
	# Notification hook for debugging or particle effects
	pass
