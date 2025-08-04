extends Area2D

func _ready():
	var bodies = get_overlapping_bodies()
	for body in bodies:
		print("Colisiona con: ", body.name)

