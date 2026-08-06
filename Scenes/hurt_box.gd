#Hurtbox
#Receives attacks from Hitboxes
extends Area2D

# Sent when an attack reaches this hurtbox
signal hit_received(hitbox)
func _ready():
	#body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

#func _on_body_entered(body):
	#print("Body entered:", body.name)

func _on_area_entered(area):
	print("Enemy Was Hit!")
	# Notiffy the owning object that it has been hit
	emit_signal("hit_received", area) 
