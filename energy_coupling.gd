## Couples an exergonic (energy-releasing) reaction to an endergonic (energy-consuming) one
## Example: ATP hydrolysis powering glucose phosphorylation
class_name EnergyCoupling
extends RefCounted

var energy_source: Reaction  # Exergonic reaction (e.g., ATP → ADP + Pi)
var energy_sink: Reaction    # Endergonic reaction (e.g., Glucose + Pi → G6P)
var coupling_efficiency: float = 0.8  # 80% energy transfer efficiency

## Coupling state
var is_active: bool = true
var total_energy_transferred: float = 0.0

func can_couple() -> bool:
	"""Check if coupling is possible"""
	if not is_active:
		return false
	
	if not energy_source or not energy_sink:
		return false
	
	# Source must be releasing energy
	if energy_source.current_delta_g_actual >= 0:
		return false
	
	# Sink must be consuming energy
	if energy_sink.current_delta_g_actual <= 0:
		return false
	
	# Source must provide enough energy
	var available_energy = -energy_source.current_delta_g_actual
	var required_energy = energy_sink.current_delta_g_actual
	
	return available_energy * coupling_efficiency >= required_energy

func apply_coupling(delta: float) -> void:
	"""Transfer energy from source to sink"""
	if not can_couple():
		return
	
	# Calculate available energy from source
	var available_energy = -energy_source.current_delta_g_actual
	var required_energy = energy_sink.current_delta_g_actual
	
	# Transfer energy with efficiency loss
	var energy_transferred = min(
		available_energy * coupling_efficiency,
		required_energy
	)
	
	# Reduce the sink's energy barrier
	# This makes the unfavorable reaction more favorable
	energy_sink.effective_delta_g = energy_sink.current_delta_g_actual - energy_transferred
	
	# Track total energy transferred
	total_energy_transferred += energy_transferred * delta
	
	# The "waste" heat is the inefficiency
	var waste_heat = available_energy * (1.0 - coupling_efficiency)
	# This will be picked up by Cell's heat tracking through reaction.current_heat_generated

func get_coupling_ratio() -> float:
	"""Get the stoichiometric coupling ratio"""
	if not energy_source or not energy_sink:
		return 1.0
	
	var source_energy = abs(energy_source.delta_g)
	var sink_energy = abs(energy_sink.delta_g)
	
	# How many source molecules needed per sink molecule
	return ceil(sink_energy / (source_energy * coupling_efficiency))

func get_summary() -> String:
	"""Get human-readable summary of coupling"""
	if not energy_source or not energy_sink:
		return "Invalid coupling"
	
	var ratio = get_coupling_ratio()
	return "%s (%d×) → %s (%.0f%% efficient)" % [
		energy_source.name,
		ratio,
		energy_sink.name,
		coupling_efficiency * 100
	]
