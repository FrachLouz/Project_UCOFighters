extends Area2D

onready var player_path = get_parent().get_path()

func take_hit(object_path: NodePath, killing_blow: bool):
	get_node(player_path).manage_hit(object_path, killing_blow)
