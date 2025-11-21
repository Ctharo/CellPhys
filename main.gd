## Main scene entry point for Biochemistry Simulator
extends Control

func _ready() -> void:
	var simulator = Simulator.new()
	simulator.name = "SimEngine"
	add_child(simulator)
	print("✅ Dynamic Biochemistry Simulator launched!")
	print("🔬 Random molecules and reactions with efficiency-based heat waste")
	print("📊 Reaction efficiency affects both heat loss and product similarity\n")
