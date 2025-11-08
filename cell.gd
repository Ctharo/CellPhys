class_name Cell
extends Node

## Builds up with wasted energy from reactions
var heat: float = 0.0
## List of enzymes
var enzymes: Array[Enzyme]
var spontaneous_reactions: Array[Reaction] = []  # Non-enzymatic
var molecules: Dictionary = {}  # Shared molecule pool

## Energy tracking
var usable_energy_pool: float = 0.0  # Energy available for work
var total_energy_generated: float = 0.0
var total_energy_consumed: float = 0.0


## Accumulate heat from all reactions
func update_heat(delta: float) -> void:
	var heat_generated = 0.0
	
	for enzyme in enzymes:
		for reaction in enzyme.reactions:
			heat_generated += reaction.current_heat_generated
	
	for reaction in spontaneous_reactions:
		heat_generated += reaction.current_heat_generated
	
	heat += heat_generated * delta
	
	# Heat dissipation (cooling)
	var heat_loss = heat * 0.01  # 1% per second
	heat = max(0.0, heat - heat_loss * delta)

## Temperature affects reaction rates (Q10 effect)
func get_temperature_effect() -> float:
	var base_temp = 310.0  # 37°C baseline
	var current_temp = base_temp + (heat * 0.01)  # Heat increases temp
	var q10 = 2.0  # Rate doubles per 10°C increase
	return pow(q10, (current_temp - base_temp) / 10.0)
