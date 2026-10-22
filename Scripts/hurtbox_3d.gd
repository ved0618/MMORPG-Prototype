# Hurtbox 3D
# Receives attacks from Hitbox3D
class_name HurtBox3D
extends Area3D

signal hit_received(hitbox: Area3D)


func _ready() -> void:
	collision_layer = 16  # Layer 5 (Hurtboxes)
	collision_mask = 8   # Layer 4 (Hitboxes)
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area3D) -> void:
	hit_received.emit(area)
