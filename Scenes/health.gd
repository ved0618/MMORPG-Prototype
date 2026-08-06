# Health Component
# Stores health and handles damage/death
extends Node

signal health_changed(current_health, max_health)
signal died

# Editable in the Inspector
@export var max_health : int = 100
var current_health : int = 100

# Called when the node enters the scene tree for the first time.
func _ready() :
	current_health = max_health

# Reduces health and checks if the object should die
func take_damage(amount: int):
	current_health -= amount
	
	# Notify UI or other systems that health changed
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		#Notify listeners that this object has died
		emit_signal("died")
		
#func die():
	#print("Enemy Died!")
