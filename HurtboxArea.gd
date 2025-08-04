extends Area2D

onready var player_path = get_parent().get_path()

func take_hit(object_path: NodePath):
	get_node(player_path).get_hurt(object_path)
