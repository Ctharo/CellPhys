# Main.gd - Main scene entry point
# Create a Node scene and attach this script

extends Node

func _ready() -> void:
	"""Initialize the simulator"""
	var simulator = AerobicRespirationSimulatorUI.new()
	add_child(simulator)
	print("✅ Aerobic Respiration Simulator started!")
