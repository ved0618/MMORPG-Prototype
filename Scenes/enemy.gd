# Enemy
# Connects HurtBox with the Health Component
extends CharacterBody2D

@onready var hurtbox = $"HurtBox(Area2D)"
@onready var health = $"Health(Node)"

func _ready():
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)

func _on_hit_received(hitbox):
	print("Enemy received an attack! From: ", hitbox.name)
	# Ask the Health Component to proecess the damage
	health.take_damage(hitbox.get_damage())

# Called when the Health component reports death
func _on_died():
	print("Enemy Died!")
