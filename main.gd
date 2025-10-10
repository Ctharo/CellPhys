## Main scene entry point for Biochemistry Simulator
## Attach this script to a Node in your scene

extends Node

func _ready() -> void:
	## Create and initialize the UI
	var ui = BiochemistryMapUI.new()
	add_child(ui)
	print("✅ Biochemistry Simulator launched!")
