extends Area2D

onready var host_player = get_tree().get_root().get_node("Main/HostPlayer").get_path()
onready var active_timer = $ActiveTimer

var player_path = null
var killing_blow = false

func _network_spawn(data: Dictionary) -> void:
	
	player_path = data['player_path']
	
	if not data['inverse']:
		global_position = data['position']
	else:
		global_position = Vector2(data['position'].x + data['offset'], data['position'].y)
		scale.x = -1
	active_timer.start()

func _network_process(input:Dictionary):
	check_colission()

func _on_ActiveTimer_timeout():
	SyncManager.despawn(self)

func check_colission():
	for body in get_overlapping_areas():
		if player_path != body.player_path:
			if body.has_method("take_hit"):
				body.take_hit(player_path, killing_blow)
