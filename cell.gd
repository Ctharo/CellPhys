## Cell manages thermal dynamics and energy pools
## Heat accumulation from inefficient reactions
## Cell dies if heat exceeds threshold or drops too low
class_name Cell
extends RefCounted

## Thermal state
var heat: float = 50.0  ## Current heat level (arbitrary units)
var min_heat_threshold: float = 20.0  ## Cell dies if below
var max_heat_threshold: float = 150.0  ## Cell dies if above
var baseline_heat_loss: float = 0.5  ## Heat dissipation rate per second

## Energy pools
var usable_energy_pool: float = 100.0  ## Energy available for endergonic reactions
var total_energy_generated: float = 0.0  ## Cumulative tracking
var total_energy_consumed: float = 0.0
var total_heat_generated: float = 0.0

## Survival status
var is_alive: bool = true
var death_reason: String = ""

## References to cell components
var molecules: Dictionary = {}
var enzymes: Array[Enzyme] = []

func _init() -> void:
	pass

## Update heat from reactions
func update_heat(delta: float, reactions: Array[Reaction]) -> void:
	if not is_alive:
		return
	
	var heat_generated_this_frame = 0.0
	
	## Accumulate heat from all reactions
	for reaction in reactions:
		## Use actual property from reaction.gd: current_heat_generated
		heat_generated_this_frame += reaction.current_heat_generated
	
	## Add to total heat
	heat += heat_generated_this_frame * delta
	total_heat_generated += heat_generated_this_frame * delta
	
	## Natural heat loss (proportional to current heat)
	var heat_loss = heat * baseline_heat_loss * delta
	heat -= heat_loss
	
	## Check survival thresholds
	check_survival()

## Update usable energy pool from reactions
func update_energy_pool(delta: float, reactions: Array[Reaction]) -> void:
	if not is_alive:
		return
	
	var energy_change = 0.0
	
	for reaction in reactions:
		var net_rate = reaction.current_forward_rate - reaction.current_reverse_rate
		if net_rate > 0:
			## Use actual property from reaction.gd: current_useful_work
			energy_change += reaction.current_useful_work
			
			## Track totals
			if reaction.current_useful_work > 0:
				total_energy_generated += reaction.current_useful_work * delta
			else:
				total_energy_consumed += abs(reaction.current_useful_work) * delta
	
	## Update pool
	usable_energy_pool += energy_change * delta
	usable_energy_pool = max(usable_energy_pool, 0.0)  ## Can't go negative

## Check if cell survives current conditions
func check_survival() -> void:
	return
	#if not is_alive:
		#return
	#
	### Death from overheating
	#if heat > max_heat_threshold:
		#is_alive = false
		#death_reason = "Thermal runaway (heat > %.1f)" % max_heat_threshold
		#print("💀 Cell died: %s" % death_reason)
		#return
	#
	### Death from cooling
	#if heat < min_heat_threshold:
		#is_alive = false
		#death_reason = "Insufficient metabolism (heat < %.1f)" % min_heat_threshold
		#print("💀 Cell died: %s" % death_reason)
		#return

## Get thermal status
func get_thermal_status() -> Dictionary:
	return {
		"heat": heat,
		"min_threshold": min_heat_threshold,
		"max_threshold": max_heat_threshold,
		"heat_ratio": heat / max_heat_threshold,
		"is_alive": is_alive
	}

## Get energy status
func get_energy_status() -> Dictionary:
	return {
		"usable_energy": usable_energy_pool,
		"total_generated": total_energy_generated,
		"total_consumed": total_energy_consumed,
		"total_heat": total_heat_generated,
		"net_energy": total_energy_generated - total_energy_consumed
	}

## Temperature affects reaction rates (Q10 effect)
func get_temperature_modifier() -> float:
	var base_temp = 310.0  ## 37°C baseline
	## Simple linear relationship for now
	var temp_offset = (heat - 50.0) * 0.2  ## ±10°C at extremes
	var current_temp = base_temp + temp_offset
	var q10 = 2.0
	return pow(q10, (current_temp - base_temp) / 10.0)
