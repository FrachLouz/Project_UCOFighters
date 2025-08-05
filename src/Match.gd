extends Node2D

const main = preload("res://src/Main.tscn")

func _ready():
	$ClientPlayer.set_network_master(main.client_id)
	$HostPlayer.set_network_master(main.host_id)
	
	SyncManager.start()
