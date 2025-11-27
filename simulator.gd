## Simulation engine - manages molecules, enzymes, and reactions
class_name Simulator
extends Node

signal simulation_updated
signal molecule_changed(molecule_name: String, new_concentration: float)

#region State

var molecules: Dictionary = {}  ## {name: Molecule}
var enzymes: Array[Enzyme] = []
var cell: Cell

var is_paused: bool = false
var simulation_speed: float = 1.0
var elapsed_time: float = 0.0

#endregion

#region Initialization

func _ready() -> void:
	cell = Cell.new()
	setup_minimal_system()
	print_system_summary()

## Create a minimal 2-enzyme, 2-reaction system for testing
func setup_minimal_system() -> void:
	## Create 3 molecules: A → B → C (linear pathway)
	var mol_a = Molecule.new("Molecule_A", 5.0, [1, 2, 3, 4, 5])
	var mol_b = Molecule.new("Molecule_B", 1.0, [1, 2, 3, 5, 6])
	var mol_c = Molecule.new("Molecule_C", 0.1, [1, 2, 4, 6, 7])
	
	## Set meaningful energy levels
	mol_a.potential_energy = 60.0  ## High energy substrate
	mol_b.potential_energy = 45.0  ## Medium energy intermediate
	mol_c.potential_energy = 30.0  ## Low energy product
	
	molecules["Molecule_A"] = mol_a
	molecules["Molecule_B"] = mol_b
	molecules["Molecule_C"] = mol_c
	
	## Enzyme 1: Catalyzes A → B (exergonic)
	var enzyme1 = Enzyme.new("E1", "Kinase_Alpha")
	enzyme1.concentration = 0.005
	
	var rxn1 = Reaction.new("R1", "A_to_B")
	rxn1.substrates = {"Molecule_A": 1.0}
	rxn1.products = {"Molecule_B": 1.0}
	rxn1.delta_g = -8.0  ## Exergonic (favorable)
	rxn1.vmax = 5.0
	rxn1.km = 1.0
	rxn1.reaction_efficiency = 0.75
	
	enzyme1.add_reaction(rxn1)
	enzymes.append(enzyme1)
	
	## Enzyme 2: Catalyzes B → C (exergonic)
	var enzyme2 = Enzyme.new("E2", "Phosphatase_Beta")
	enzyme2.concentration = 0.003
	
	var rxn2 = Reaction.new("R2", "B_to_C")
	rxn2.substrates = {"Molecule_B": 1.0}
	rxn2.products = {"Molecule_C": 1.0}
	rxn2.delta_g = -5.0  ## Exergonic (favorable)
	rxn2.vmax = 3.0
	rxn2.km = 0.5
	rxn2.reaction_efficiency = 0.65
	
	enzyme2.add_reaction(rxn2)
	enzymes.append(enzyme2)

#endregion

#region Simulation Loop

func _process(delta: float) -> void:
	if is_paused or not cell.is_alive:
		return
	
	var dt = delta * simulation_speed
	elapsed_time += dt
	
	## Update all enzyme reaction rates
	for enzyme in enzymes:
		enzyme.update_reaction_rates(molecules)
	
	## Apply concentration changes
	apply_concentration_changes(dt)
	
	## Collect all reactions for cell update
	var all_reactions: Array[Reaction] = []
	for enzyme in enzymes:
		all_reactions.append_array(enzyme.reactions)
	
	## Update cell thermal and energy state
	cell.update(dt, all_reactions)
	
	simulation_updated.emit()

func apply_concentration_changes(dt: float) -> void:
	## Calculate concentration deltas from all reactions
	var deltas: Dictionary = {}
	for mol_name in molecules:
		deltas[mol_name] = 0.0
	
	for enzyme in enzymes:
		for reaction in enzyme.reactions:
			var net_rate = reaction.get_net_rate()
			
			## Substrates consumed
			for substrate in reaction.substrates:
				if deltas.has(substrate):
					deltas[substrate] -= net_rate * reaction.substrates[substrate]
			
			## Products produced
			for product in reaction.products:
				if deltas.has(product):
					deltas[product] += net_rate * reaction.products[product]
	
	## Apply deltas
	for mol_name in deltas:
		var mol = molecules[mol_name]
		mol.concentration += deltas[mol_name] * dt
		mol.concentration = max(mol.concentration, 0.0)
		molecule_changed.emit(mol_name, mol.concentration)

#endregion

#region Controls

func toggle_pause() -> void:
	is_paused = not is_paused

func set_speed(speed: float) -> void:
	simulation_speed = clamp(speed, 0.1, 100.0)

func reset() -> void:
	elapsed_time = 0.0
	for mol in molecules.values():
		mol.concentration = mol.initial_concentration
	cell = Cell.new()

#endregion

#region Debug Output

func print_system_summary() -> void:
	print("\n" + "=".repeat(50))
	print("BIOCHEMISTRY SIMULATOR - Minimal Test System")
	print("=".repeat(50))
	
	print("\n📦 MOLECULES (%d):" % molecules.size())
	for mol in molecules.values():
		print("  • %s" % mol.get_summary())
	
	print("\n🧬 ENZYMES (%d):" % enzymes.size())
	for enzyme in enzymes:
		print("  • %s" % enzyme.get_summary())
		for rxn in enzyme.reactions:
			print("    └─ %s (ΔG°=%.1f, eff=%.0f%%)" % [
				rxn.get_summary(), rxn.delta_g, rxn.reaction_efficiency * 100
			])
	
	print("\n" + "=".repeat(50) + "\n")

func get_status_text() -> String:
	var text = "Time: %.1fs | Speed: %.1fx | %s\n\n" % [
		elapsed_time,
		simulation_speed,
		"PAUSED" if is_paused else "RUNNING"
	]
	
	text += "── MOLECULES ──\n"
	for mol in molecules.values():
		text += "  %s: %.3f mM (E=%.1f)\n" % [mol.name, mol.concentration, mol.potential_energy]
	
	text += "\n── REACTIONS ──\n"
	for enzyme in enzymes:
		for rxn in enzyme.reactions:
			text += "  %s\n" % rxn.get_summary()
			text += "    Rate: %.3f mM/s, ΔG: %.1f kJ/mol\n" % [
				rxn.get_net_rate(), rxn.current_delta_g_actual
			]
			text += "    Work: %.2f, Heat: %.2f kJ/s\n" % [
				rxn.current_useful_work, rxn.current_heat_generated
			]
	
	text += "\n── CELL ──\n"
	var thermal = cell.get_thermal_status()
	var energy = cell.get_energy_status()
	text += "  Heat: %.1f (%.0f - %.0f range)\n" % [
		thermal.heat, thermal.min_threshold, thermal.max_threshold
	]
	text += "  Energy Pool: %.1f kJ\n" % energy.usable_energy
	text += "  Total Heat Generated: %.2f kJ\n" % energy.total_heat
	
	return text

## Get BBCode formatted status for RichTextLabel
func get_formatted_status() -> String:
	var status_color = "[color=#88ff88]RUNNING[/color]" if not is_paused else "[color=#ffaa44]PAUSED[/color]"
	var text = "[font_size=16][b]Time:[/b] %.1fs   [b]Speed:[/b] %.0fx   %s[/font_size]\n\n" % [
		elapsed_time,
		simulation_speed,
		status_color
	]
	
	## Molecules section
	text += "[font_size=18][color=#88ccff][b]📦 MOLECULES[/b][/color][/font_size]\n"
	text += "[font_size=14]"
	for mol in molecules.values():
		var conc_color = _get_concentration_color(mol.concentration, mol.initial_concentration)
		text += "  [color=#aaaaaa]•[/color] [b]%s[/b]: [color=%s]%.3f mM[/color]  [color=#888888](E=%.1f kJ/mol)[/color]\n" % [
			mol.name, conc_color, mol.concentration, mol.potential_energy
		]
	text += "[/font_size]\n"
	
	## Enzymes section
	text += "[font_size=18][color=#ffcc66][b]🧬 ENZYMES[/b][/color][/font_size]\n"
	text += "[font_size=14]"
	for enzyme in enzymes:
		text += "  [color=#ffcc66][b]%s[/b][/color] [color=#888888][%.4f mM][/color]\n" % [
			enzyme.name, enzyme.concentration
		]
		for rxn in enzyme.reactions:
			var rate_color = _get_rate_color(rxn.get_net_rate())
			text += "    [color=#aaaaaa]└─[/color] %s\n" % _format_reaction(rxn)
			text += "       [color=#888888]Rate:[/color] [color=%s]%.3f mM/s[/color]  " % [rate_color, rxn.get_net_rate()]
			text += "[color=#888888]ΔG:[/color] [color=#cc99ff]%.1f kJ/mol[/color]\n" % rxn.current_delta_g_actual
			text += "       [color=#888888]Work:[/color] [color=#88ff88]%.2f[/color]  " % rxn.current_useful_work
			text += "[color=#888888]Heat:[/color] [color=#ff8866]%.2f kJ/s[/color]\n" % rxn.current_heat_generated
	text += "[/font_size]\n"
	
	## Cell section
	text += "[font_size=18][color=#ff8888][b]🔬 CELL STATUS[/b][/color][/font_size]\n"
	text += "[font_size=14]"
	var thermal = cell.get_thermal_status()
	var energy = cell.get_energy_status()
	var heat_color = _get_heat_color(thermal.heat, thermal.max_threshold)
	text += "  [color=#888888]Heat:[/color] [color=%s]%.1f[/color] [color=#666666](range: %.0f - %.0f)[/color]\n" % [
		heat_color, thermal.heat, thermal.min_threshold, thermal.max_threshold
	]
	text += "  [color=#888888]Energy Pool:[/color] [color=#88ff88]%.1f kJ[/color]\n" % energy.usable_energy
	text += "  [color=#888888]Total Heat:[/color] [color=#ff8866]%.2f kJ[/color]\n" % energy.total_heat
	text += "[/font_size]"
	
	return text

func _format_reaction(rxn: Reaction) -> String:
	var substrate_str = ""
	for substrate in rxn.substrates:
		if substrate_str != "":
			substrate_str += " + "
		substrate_str += "[color=#88ccff]%s[/color]" % substrate
	
	var product_str = ""
	for product in rxn.products:
		if product_str != "":
			product_str += " + "
		product_str += "[color=#88ff88]%s[/color]" % product
	
	if substrate_str == "":
		substrate_str = "∅"
	if product_str == "":
		product_str = "∅"
	
	var arrow = "→" if rxn.is_irreversible else "⇄"
	return "%s %s %s" % [substrate_str, arrow, product_str]

func _get_concentration_color(current: float, initial: float) -> String:
	var ratio = current / max(initial, 0.001)
	if ratio > 1.2:
		return "#88ff88"  ## Green - increasing
	elif ratio < 0.8:
		return "#ff8888"  ## Red - decreasing
	else:
		return "#ffffff"  ## White - stable

func _get_rate_color(rate: float) -> String:
	if rate > 0.1:
		return "#88ff88"  ## Green - fast forward
	elif rate < -0.1:
		return "#ff8888"  ## Red - reverse
	else:
		return "#ffff88"  ## Yellow - slow/equilibrium

func _get_heat_color(heat: float, max_heat: float) -> String:
	var ratio = heat / max_heat
	if ratio > 0.7:
		return "#ff4444"  ## Red - danger
	elif ratio > 0.5:
		return "#ffaa44"  ## Orange - warning
	else:
		return "#88ff88"  ## Green - safe

#endregion
