extends Node

signal health_changed(current_health, max_health)
signal died

@export var max_health : int = 100
var current_health : int = 100

# Called when the node enters the scene tree for the first time.
func _ready() :
	current_health = max_health


func take_damage(amount: int):
	current_health -= amount
	
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		emit_signal("died")
		
func die():
	print("Enemy Died!")
