## Main scene entry point for Biochemistry Simulator
## Attach this script to a Node in your scene

extends Node

func _ready() -> void:
	var simulator = BiochemistrySimulator.new()
	simulator.name = "SimEngine"
	add_child(simulator)
	
	var ui = BiochemistryMapUI.new(simulator)
	ui.name = "UI"
	add_child(ui)
	
	print("✅ Biochemistry Simulator launched!")
	
	# Force the UI to be visible and draw
	await get_tree().process_frame
	ui.queue_redraw()
