## CellData - manages thermal dynamics and energy pools
## Can be saved as part of simulation snapshots
class_name CellData
extends Resource

#region Thermal State

@export_group("Thermal State")
@export var temperature: float = 310.0:  ## Temperature in Kelvin (37°C body temp)
	set(value):
		temperature = clampf(value, 273.0, 373.0)  ## Keep within 0-100°C
		emit_changed()

@export var heat: float = 50.0:
	set(value):
		heat = value
		emit_changed()

@export var min_heat_threshold: float = 20.0
@export var max_heat_threshold: float = 150.0
@export var heat_dissipation_rate: float = 0.01  ## 1% per second

#endregion

#region Energy Pools

@export_group("Energy Pools")
@export var usable_energy: float = 100.0:
	set(value):
		usable_energy = maxf(0.0, value)
		emit_changed()

@export var total_energy_generated: float = 0.0
@export var total_energy_consumed: float = 0.0
@export var total_heat_generated: float = 0.0

#endregion

#region Survival

@export_group("Survival")
@export var is_alive: bool = true
@export var death_reason: String = ""

#endregion

#region Initialization

func _init() -> void:
	pass

## Create a fresh instance
static func create_new() -> CellData:
	var cell = CellData.new()
	cell.temperature = 310.0
	cell.heat = 50.0
	cell.usable_energy = 100.0
	cell.is_alive = true
	return cell

## Create a runtime instance from this resource template
func create_instance() -> CellData:
	return duplicate(true) as CellData

## Reset to initial state
func reset() -> void:
	temperature = 310.0
	heat = 50.0
	usable_energy = 100.0
	total_energy_generated = 0.0
	total_energy_consumed = 0.0
	total_heat_generated = 0.0
	is_alive = true
	death_reason = ""

#endregion

#region Updates

func update(delta: float, reactions: Array) -> void:
	if not is_alive:
		return
	
	update_heat(delta, reactions)
	update_energy(delta, reactions)
	check_survival()

func update_heat(delta: float, reactions: Array) -> void:
	var heat_this_frame = 0.0
	for reaction in reactions:
		heat_this_frame += reaction.current_heat_generated
	
	heat += heat_this_frame * delta
	total_heat_generated += heat_this_frame * delta
	
	## Natural dissipation
	heat -= heat * heat_dissipation_rate * delta
	heat = maxf(0.0, heat)

func update_energy(delta: float, reactions: Array) -> void:
	var energy_change = 0.0
	
	for reaction in reactions:
		if reaction.get_net_rate() > 0:
			if reaction.current_useful_work > 0:
				total_energy_generated += reaction.current_useful_work * delta
			else:
				total_energy_consumed += abs(reaction.current_useful_work) * delta
			energy_change += reaction.current_useful_work
	
	usable_energy += energy_change * delta
	usable_energy = maxf(usable_energy, 0.0)

func check_survival() -> void:
	## TEST -> Keep alive for now
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
		"temperature": temperature,
		"heat": heat,
		"min_threshold": min_heat_threshold,
		"max_threshold": max_heat_threshold,
		"heat_ratio": heat / max_heat_threshold if max_heat_threshold > 0 else 0.0,
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

func _to_string() -> String:
	return "CellData(T=%.1fK, heat=%.1f, energy=%.1f, %s)" % [
		temperature, heat, usable_energy, "alive" if is_alive else "dead"
	]

#endregion
