## Simple UI for displaying simulation state
extends Control

@onready var status_label: RichTextLabel = %StatusLabel
@onready var pause_button: Button = %PauseButton
@onready var reset_button: Button = %ResetButton
@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_label: Label = %SpeedLabel
@onready var chart_panel: Panel = %ChartPanel

var simulator: Simulator = null

## Concentration history for charting
var concentration_history: Dictionary = {}  ## {mol_name: Array[float]}
var history_max_points: int = 300
var update_counter: int = 0
var update_interval: int = 2  ## Record every N frames

func _ready() -> void:
	await get_tree().process_frame
	simulator = get_node_or_null("SimEngine")
	
	if simulator:
		simulator.simulation_updated.connect(_on_simulation_updated)
		## Initialize history arrays
		for mol_name in simulator.molecules:
			concentration_history[mol_name] = []
		_on_simulation_updated()
	else:
		status_label.text = "ERROR: Simulator not found!"

func _on_simulation_updated() -> void:
	if not simulator:
		return
	
	status_label.text = simulator.get_formatted_status()
	
	## Record concentration history periodically
	update_counter += 1
	if update_counter >= update_interval:
		update_counter = 0
		for mol_name in simulator.molecules:
			var conc = simulator.molecules[mol_name].concentration
			if not concentration_history.has(mol_name):
				concentration_history[mol_name] = []
			concentration_history[mol_name].append(conc)
			## Trim history
			if concentration_history[mol_name].size() > history_max_points:
				concentration_history[mol_name].pop_front()
		
		chart_panel.queue_redraw()

func _on_pause_button_pressed() -> void:
	if simulator:
		simulator.toggle_pause()
		pause_button.text = "Resume" if simulator.is_paused else "Pause"

func _on_reset_button_pressed() -> void:
	if simulator:
		simulator.reset()
		pause_button.text = "Pause"
		## Clear history
		for mol_name in concentration_history:
			concentration_history[mol_name].clear()

func _on_speed_slider_value_changed(value: float) -> void:
	if simulator:
		simulator.set_speed(value)
		speed_label.text = "Speed: %.0fx" % value if value >= 1.0 else "Speed: %.1fx" % value
