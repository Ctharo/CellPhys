## Main scene entry point for Biochemistry Simulator
extends Node

func _ready() -> void:
	var simulator = Simulator.new()
	simulator.name = "SimEngine"
	add_child(simulator)
	print("✅ Dynamic Biochemistry Simulator launched!")
	print("🔬 System evolves through thermal selection pressure")
