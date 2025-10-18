## Main scene entry point for Biochemistry Simulator
## Attach this script to a Node in your scene

extends Node

func _ready() -> void:
	var simulator = SimpleEnzymeSimulator.new()
	simulator.name = "SimEngine"
	add_child(simulator)
	print("✅ Biochemistry Simulator launched!")
