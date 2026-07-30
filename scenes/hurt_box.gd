extends Area2D
signal hit_received(hitbox)
func _ready():
	#body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

#func _on_body_entered(body):
	#print("Body entered:", body.name)

func _on_area_entered(area):
	print("Enemy Was Hit!")
	
	emit_signal("hit_received", area) 
