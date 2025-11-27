## UI controller for Biochemistry Simulator
extends Control

#region Node References

@onready var sim_engine: Simulator = %SimEngine
@onready var pause_button: Button = %PauseButton
@onready var reset_button: Button = %ResetButton
@onready var speed_label: Label = %SpeedLabel
@onready var speed_slider: HSlider = %SpeedSlider
@onready var left_tabs: TabContainer = %LeftTabs
@onready var cell_panel: RichTextLabel = %CellPanel
@onready var enzyme_panel: ConcentrationPanel = %EnzymePanel
@onready var molecule_panel: ConcentrationPanel = %MoleculePanel
@onready var reaction_panel: RichTextLabel = %ReactionPanel
@onready var chart_panel: ChartPanel = %ChartPanel

#endregion

#region State

var is_paused: bool = false
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  ## Update UI every 100ms

#endregion

func _ready() -> void:
	speed_slider.max_value = 10.0
	speed_slider.value = 1.0
	
	## Wait for simulator to initialize
	await get_tree().process_frame
	_populate_panels()
	_on_tab_changed(0)  ## Initialize chart mode

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_update_displays()

#region Panel Population

func _populate_panels() -> void:
	if not sim_engine:
		return
	
	## Populate enzyme panel
	enzyme_panel.clear_controls()
	for enzyme in sim_engine.enzymes:
		enzyme_panel.add_enzyme_control(enzyme.name, enzyme.concentration, enzyme.is_locked)
	
	## Populate molecule panel
	molecule_panel.clear_controls()
	for mol_name in sim_engine.molecules:
		var mol = sim_engine.molecules[mol_name]
		molecule_panel.add_molecule_control(mol_name, mol.concentration, mol.is_locked)

#endregion

#region Display Updates

func _update_displays() -> void:
	if not sim_engine:
		return
	
	var current_tab = left_tabs.current_tab
	
	match current_tab:
		0:  ## Cell
			_update_cell_display()
		1:  ## Enzymes
			enzyme_panel.update_enzymes(sim_engine.enzymes)
		2:  ## Molecules
			molecule_panel.update_molecules(sim_engine.molecules)
		3:  ## Reactions
			_update_reaction_display()

func _update_cell_display() -> void:
	if not sim_engine or not sim_engine.cell:
		cell_panel.text = "No cell data available"
		return
	
	var thermal = sim_engine.cell.get_thermal_status()
	var energy = sim_engine.cell.get_energy_status()
	
	var text = "[b]═══════ SIMULATION ═══════[/b]\n\n"
	text += "[b]⏱ Time:[/b] %.2fs\n" % sim_engine.simulation_time
	text += "[b]⚡ Speed:[/b] %.1fx\n" % sim_engine.time_scale
	text += "[b]🔄 State:[/b] %s\n\n" % ("PAUSED" if is_paused else "RUNNING")
	
	text += "[b]═══════ THERMAL ═══════[/b]\n\n"
	text += "[b]🌡 Current Heat:[/b] [color=#ffaa66]%.2f[/color]\n" % thermal.heat
	text += "[b]📉 Min Threshold:[/b] %.1f\n" % thermal.min_threshold
	text += "[b]📈 Max Threshold:[/b] %.1f\n" % thermal.max_threshold
	
	var heat_percent = (thermal.heat - thermal.min_threshold) / (thermal.max_threshold - thermal.min_threshold) * 100
	text += "[b]📊 Heat Level:[/b] %.1f%%\n\n" % heat_percent
	
	text += "[b]═══════ ENERGY ═══════[/b]\n\n"
	text += "[b]⚡ Usable Energy:[/b] [color=#88ff88]%.2f kJ[/color]\n" % energy.usable_energy
	text += "[b]📈 Total Generated:[/b] %.2f kJ\n" % energy.total_generated
	text += "[b]📉 Total Consumed:[/b] %.2f kJ\n" % energy.total_consumed
	text += "[b]🔥 Heat Waste:[/b] %.2f kJ\n" % energy.total_heat
	text += "[b]📊 Net Energy:[/b] %.2f kJ\n\n" % energy.net_energy
	
	## Efficiency calculation
	if energy.total_generated > 0:
		var efficiency = (energy.total_generated - energy.total_heat) / energy.total_generated * 100
		text += "[b]⚙ System Efficiency:[/b] %.1f%%\n" % efficiency
	
	text += "\n[b]═══════ STATUS ═══════[/b]\n\n"
	if thermal.is_alive:
		text += "[color=#88ff88]✅ Cell is alive and functioning[/color]\n"
	else:
		text += "[color=#ff6666]❌ Cell death: %s[/color]\n" % sim_engine.cell.death_reason
	
	cell_panel.text = text

func _update_reaction_display() -> void:
	if not sim_engine:
		reaction_panel.text = "No reaction data available"
		return
	
	var text = "[b]═══════ ACTIVE REACTIONS ═══════[/b]\n\n"
	
	var total_reactions = 0
	var active_reactions = 0
	
	for enzyme in sim_engine.enzymes:
		if enzyme.reactions.is_empty():
			continue
		
		text += "[b]🔷 %s[/b] [%.4f mM]%s\n" % [
			enzyme.name, 
			enzyme.concentration,
			" 🔒" if enzyme.is_locked else ""
		]
		
		for rxn in enzyme.reactions:
			total_reactions += 1
			var net_rate = rxn.get_net_rate()
			
			## Reaction equation
			var direction_icon = "→" if net_rate >= 0 else "←"
			var rate_color = "#88ff88" if net_rate > 0.001 else ("#ff8888" if net_rate < -0.001 else "#888888")
			
			if abs(net_rate) > 0.0001:
				active_reactions += 1
			
			text += "  [b]%s[/b]\n" % rxn.get_summary()
			text += "    Rate: [color=%s]%.4f mM/s %s[/color]\n" % [rate_color, abs(net_rate), direction_icon]
			text += "    ΔG°: %.2f → ΔG: %.2f kJ/mol\n" % [rxn.delta_g, rxn.current_delta_g_actual]
			text += "    Efficiency: %.0f%% | Keq: %.2e\n" % [rxn.reaction_efficiency * 100, rxn.current_keq]
			
			if rxn.current_useful_work != 0 or rxn.current_heat_generated != 0:
				text += "    Work: %.3f | Heat: %.3f kJ/s\n" % [rxn.current_useful_work, rxn.current_heat_generated]
			text += "\n"
		
		text += "\n"
	
	## Summary
	text += "[b]═══════ SUMMARY ═══════[/b]\n\n"
	text += "[b]Total Reactions:[/b] %d\n" % total_reactions
	text += "[b]Active (|rate| > 0.0001):[/b] %d\n" % active_reactions
	
	## Calculate total flux
	var total_forward_flux = 0.0
	var total_reverse_flux = 0.0
	for enzyme in sim_engine.enzymes:
		for rxn in enzyme.reactions:
			total_forward_flux += rxn.current_forward_rate
			total_reverse_flux += rxn.current_reverse_rate
	
	text += "[b]Total Forward Flux:[/b] %.3f mM/s\n" % total_forward_flux
	text += "[b]Total Reverse Flux:[/b] %.3f mM/s\n" % total_reverse_flux
	
	reaction_panel.text = text

#endregion

#region Tab Changed Handler

func _on_tab_changed(tab_index: int) -> void:
	## Update chart mode based on selected tab
	if not chart_panel:
		return
	
	match tab_index:
		0:  ## Cell
			chart_panel.set_mode(ChartPanel.ChartMode.CELL)
		1:  ## Enzymes
			chart_panel.set_mode(ChartPanel.ChartMode.ENZYMES)
		2:  ## Molecules
			chart_panel.set_mode(ChartPanel.ChartMode.MOLECULES)
		3:  ## Reactions
			chart_panel.set_mode(ChartPanel.ChartMode.REACTIONS)

#endregion

#region Concentration Change Handlers

func _on_molecule_concentration_changed(mol_name: String, new_value: float, _is_enzyme: bool) -> void:
	if sim_engine and sim_engine.molecules.has(mol_name):
		sim_engine.molecules[mol_name].concentration = new_value

func _on_enzyme_concentration_changed(enz_name: String, new_value: float, _is_enzyme: bool) -> void:
	if not sim_engine:
		return
	
	for enzyme in sim_engine.enzymes:
		if enzyme.name == enz_name:
			enzyme.concentration = new_value
			break

func _on_molecule_lock_changed(mol_name: String, is_locked: bool, _is_enzyme: bool) -> void:
	if sim_engine and sim_engine.molecules.has(mol_name):
		sim_engine.molecules[mol_name].is_locked = is_locked

func _on_enzyme_lock_changed(enz_name: String, is_locked: bool, _is_enzyme: bool) -> void:
	if not sim_engine:
		return
	
	for enzyme in sim_engine.enzymes:
		if enzyme.name == enz_name:
			enzyme.is_locked = is_locked
			break

#endregion

#region UI Callbacks

func _on_pause_button_pressed() -> void:
	is_paused = not is_paused
	pause_button.text = "Resume" if is_paused else "Pause"
	
	if sim_engine:
		sim_engine.set_paused(is_paused)

func _on_reset_button_pressed() -> void:
	if sim_engine:
		sim_engine.reset_simulation()
		_populate_panels()
	
	if chart_panel:
		chart_panel.clear_history()

func _on_speed_slider_value_changed(value: float) -> void:
	speed_label.text = "Speed: %.1fx" % value
	
	if sim_engine:
		sim_engine.time_scale = value

#endregion
