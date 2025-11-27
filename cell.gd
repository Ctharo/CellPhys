## Cell manages thermal dynamics and energy pools
class_name Cell
extends RefCounted

#region Thermal State

var heat: float = 50.0
var min_heat_threshold: float = 20.0
var max_heat_threshold: float = 150.0
var heat_dissipation_rate: float = 0.5  ## Per second

#endregion

#region Energy Pools

var usable_energy: float = 100.0
var total_energy_generated: float = 0.0
var total_energy_consumed: float = 0.0
var total_heat_generated: float = 0.0

#endregion

#region Survival

var is_alive: bool = true
var death_reason: String = ""

#endregion

func _init() -> void:
	pass

#region Updates

func update(delta: float, reactions: Array[Reaction]) -> void:
	if not is_alive:
		return
	
	update_heat(delta, reactions)
	update_energy(delta, reactions)
	check_survival()

func update_heat(delta: float, reactions: Array[Reaction]) -> void:
	var heat_this_frame = 0.0
	for reaction in reactions:
		heat_this_frame += reaction.current_heat_generated
	
	heat += heat_this_frame * delta
	total_heat_generated += heat_this_frame * delta
	
	## Natural dissipation
	heat -= heat * heat_dissipation_rate * delta

func update_energy(delta: float, reactions: Array[Reaction]) -> void:
	var energy_change = 0.0
	
	for reaction in reactions:
		if reaction.get_net_rate() > 0:
			if reaction.current_useful_work > 0:
				total_energy_generated += reaction.current_useful_work * delta
			else:
				total_energy_consumed += abs(reaction.current_useful_work) * delta
			energy_change += reaction.current_useful_work
	
	usable_energy += energy_change * delta
	usable_energy = max(usable_energy, 0.0)

func check_survival() -> void:
	# TEST -> Keep alive for now, dying immediately
	return
	
	@warning_ignore("unreachable_code")
	if heat > max_heat_threshold:
		is_alive = false
		death_reason = "Thermal runaway (heat > %.1f)" % max_heat_threshold
	elif heat < min_heat_threshold:
		is_alive = false
		death_reason = "Insufficient metabolism (heat < %.1f)" % min_heat_threshold

#endregion

#region Status

func get_thermal_status() -> Dictionary:
	return {
		"heat": heat,
		"min_threshold": min_heat_threshold,
		"max_threshold": max_heat_threshold,
		"heat_ratio": heat / max_heat_threshold,
		"is_alive": is_alive
	}

func get_energy_status() -> Dictionary:
	return {
		"usable_energy": usable_energy,
		"total_generated": total_energy_generated,
		"total_consumed": total_energy_consumed,
		"total_heat": total_heat_generated,
		"net_energy": total_energy_generated - total_energy_consumed
	}

#endregion
