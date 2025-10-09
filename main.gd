# Main.gd - Main scene controller for Aerobic Respiration Simulator
# Attach this to a Node in your main scene

extends Node

class_name Main

@onready var simulator: AerobicRespirationSimulatorUI

func _ready() -> void:
	"""Initialize the simulator and set up the main scene"""
	
	# Create the simulator node
	simulator = AerobicRespirationSimulatorUI.new()
	add_child(simulator)
	
	print("✅ Aerobic Respiration Simulator initialized!")
	print("Controls:")
	print("  [SPACE] - Add glucose")
	print("  [O] - Toggle hypoxia")
	print("  [R] - Reset simulation")
	print("  [P] - Pause/Resume")
	print("  [+/-] - Speed up/slow down") 

func _process(_delta: float) -> void:
	"""Handle user input"""
	
	if Input.is_action_just_pressed("ui_text_backspace"):
		simulator.add_glucose(5.0)
	
	if Input.is_action_just_pressed("ui_accept"):  # Enter key
		simulator.add_glucose(10.0)
	
	if Input.is_action_just_pressed("ui_home"):  # Could map to 'R' key
		reset_simulation()
	
	# Custom input for oxygen stress
	if Input.is_key_pressed(KEY_O):
		simulator.oxygen = 0.01
	
	# Speed controls
	if Input.is_key_pressed(KEY_PLUS) or Input.is_key_pressed(KEY_EQUAL):
		simulator.timestep = max(simulator.timestep - 0.001, 0.01)
	
	if Input.is_key_pressed(KEY_MINUS):
		simulator.timestep = min(simulator.timestep + 0.001, 0.5)

func reset_simulation() -> void:
	"""Reset the simulator to initial state"""
	simulator.glucose = 5.0
	simulator.pyruvate = 0.1
	simulator.acetyl_coa = 0.05
	simulator.citrate = 0.1
	simulator.isocitrate = 0.05
	simulator.alpha_ketoglutarate = 0.08
	simulator.succinate = 0.1
	simulator.malate = 0.1
	simulator.oxaloacetate = 0.15
	simulator.nadh = 0.5
	simulator.nad = 5.0
	simulator.atp = 2.0
	simulator.adp = 3.0
	simulator.oxygen = 1.0
	simulator.co2 = 0.1
	
	print("🔄 Simulation reset!")
