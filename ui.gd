## Main UI controller - handles logic for scene-based layout
extends Control

#region Enums

enum LayoutMode { ALL_PANELS, FOCUS_CHART, FOCUS_GENES, TWO_COLUMN, COMPACT }
enum ChartMode { MOLECULES, ENZYMES, BOTH }

#endregion

#region Node References

@onready var sim_engine: Simulator = %SimEngine

## Toolbar
@onready var pause_button: Button = %PauseButton
@onready var reset_button: Button = %ResetButton
@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_value: Label = %SpeedValue
@onready var layout_option: OptionButton = %LayoutOption
@onready var view_menu: MenuButton = %ViewMenu
@onready var chart_mode_option: OptionButton = %ChartModeOption
@onready var auto_scale_check: CheckBox = %AutoScaleCheck

## Main layout
@onready var main_area: Control = %MainArea
@onready var hsplit1: HSplitContainer = %HSplit1
@onready var hsplit2: HSplitContainer = %HSplit2
@onready var left_column: VSplitContainer = %LeftColumn
@onready var middle_column: VSplitContainer = %MiddleColumn
@onready var right_column: VSplitContainer = %RightColumn

## Dock panels
@onready var cell_dock: DockPanel = %CellPanel
@onready var reactions_dock: DockPanel = %ReactionsPanel
@onready var enzymes_dock: DockPanel = %EnzymesPanel
@onready var molecules_dock: DockPanel = %MoleculesPanel
@onready var genes_dock: DockPanel = %GenesPanel
@onready var chart_dock: DockPanel = %ChartDock

## Content panels
@onready var cell_content: RichTextLabel = %CellContent
@onready var reactions_content: RichTextLabel = %ReactionsContent
@onready var enzyme_panel: ConcentrationPanel = %EnzymePanel
@onready var molecule_panel: ConcentrationPanel = %MoleculePanel
@onready var gene_panel: GenePanel = %GenePanel
@onready var chart_panel: ChartPanel = %ChartPanel

#endregion

#region State

var current_layout: LayoutMode = LayoutMode.ALL_PANELS
var chart_mode: ChartMode = ChartMode.MOLECULES
var is_paused: bool = false

var panel_visibility: Dictionary = {
	"cell": true,
	"reactions": true,
	"enzymes": true,
	"molecules": true,
	"genes": true,
	"chart": true
}

var all_docks: Array[DockPanel] = []

#endregion

#region Initialization

func _ready() -> void:
	_setup_view_menu()
	_cache_docks()
	
	await get_tree().process_frame
	
	_connect_signals()
	_setup_panels()

func _setup_view_menu() -> void:
	if not view_menu:
		return
	var popup = view_menu.get_popup()
	popup.clear()
	popup.add_check_item("Cell Status", 0)
	popup.add_check_item("Reactions", 1)
	popup.add_check_item("Enzymes", 2)
	popup.add_check_item("Molecules", 3)
	popup.add_check_item("Genes", 4)
	popup.add_check_item("Chart", 5)
	
	## Set all checked by default
	for i in range(6):
		popup.set_item_checked(i, true)

func _cache_docks() -> void:
	all_docks = [cell_dock, reactions_dock, enzymes_dock, molecules_dock, genes_dock, chart_dock] as Array[DockPanel]

func _connect_signals() -> void:
	## Simulator signals
	if sim_engine:
		sim_engine.simulation_updated.connect(_on_simulation_updated)
	
	## Toolbar
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if speed_slider:
		speed_slider.value_changed.connect(_on_speed_changed)
	if layout_option:
		layout_option.item_selected.connect(_on_layout_selected)
	if view_menu:
		view_menu.get_popup().id_pressed.connect(_on_view_menu_pressed)
	if chart_mode_option:
		chart_mode_option.item_selected.connect(_on_chart_mode_selected)
	if auto_scale_check:
		auto_scale_check.toggled.connect(_on_auto_scale_toggled)
	
	## Panel signals
	if enzyme_panel:
		enzyme_panel.concentration_changed.connect(_on_enzyme_concentration_changed)
		enzyme_panel.lock_changed.connect(_on_enzyme_lock_changed)
	if molecule_panel:
		molecule_panel.concentration_changed.connect(_on_molecule_concentration_changed)
		molecule_panel.lock_changed.connect(_on_molecule_lock_changed)

#endregion

#region Simulation Updates

func _on_simulation_updated(data: Dictionary) -> void:
	_update_cell_display(data)
	_update_reactions_display(data)
	_update_enzymes_panel(data)
	_update_molecules_panel(data)
	_update_genes_panel(data)
	_update_chart(data)

func _update_cell_display(data: Dictionary) -> void:
	if not cell_content or not cell_dock.visible:
		return
	
	var cell = data.get("cell")
	if not cell:
		cell_content.text = "[color=gray]No cell data[/color]"
		return
	
	var text = "[b]Cell Status[/b]\n\n"
	
	## Temperature
	var temp = cell.temperature if "temperature" in cell else 310.0
	text += "Temperature: %.1f°C\n" % [temp - 273.15]
	
	## Heat
	var heat = cell.heat if "heat" in cell else 0.0
	text += "Heat: %.2f kJ\n" % heat
	
	## Energy
	var energy = cell.usable_energy if "usable_energy" in cell else 0.0
	text += "Usable Energy: %.2f kJ\n" % energy
	
	## Status
	var is_alive = cell.is_alive if "is_alive" in cell else true
	var status_color = "lime" if is_alive else "red"
	text += "Status: [color=%s]%s[/color]\n" % [status_color, "Alive" if is_alive else "Dead"]
	
	cell_content.text = text

func _update_reactions_display(data: Dictionary) -> void:
	if not reactions_content or not reactions_dock.visible:
		return
	
	var reactions = data.get("reactions", [])
	if reactions.is_empty():
		reactions_content.text = "[color=gray]No reactions[/color]"
		return
	
	var text = ""
	for rxn in reactions:
		var summary = rxn.get_summary() if rxn.has_method("get_summary") else str(rxn)
		var net_rate = rxn.net_rate if "net_rate" in rxn else 0.0
		var efficiency = rxn.reaction_efficiency if "reaction_efficiency" in rxn else 0.0
		var delta_g = rxn.current_delta_g_actual if "current_delta_g_actual" in rxn else 0.0
		
		var rate_color = "lime" if net_rate > 0.001 else ("orange" if net_rate < -0.001 else "gray")
		
		text += "[b]%s[/b]\n" % summary
		text += "  η=%.0f%% ΔG=%.1f kJ/mol\n" % [efficiency * 100.0, delta_g]
		text += "  [color=%s]Net: %.4f mM/s[/color]\n\n" % [rate_color, net_rate]
	
	reactions_content.text = text

func _update_enzymes_panel(data: Dictionary) -> void:
	if not enzyme_panel or not enzymes_dock.visible:
		return
	var enzymes: Dictionary = data.get("enzymes", {})
	enzyme_panel.update_values(enzymes.values(), "enzyme")

func _update_molecules_panel(data: Dictionary) -> void:
	if not molecule_panel or not molecules_dock.visible:
		return
	var molecules: Dictionary = data.get("molecules", {})
	molecule_panel.update_values(molecules.values(), "molecule")

func _update_genes_panel(data: Dictionary) -> void:
	if not gene_panel or not genes_dock.visible:
		return
	var genes: Dictionary = data.get("genes", {})
	var molecules: Dictionary = data.get("molecules", {})
	var enzymes: Dictionary = data.get("enzymes", {})
	gene_panel.update_genes(genes, molecules, enzymes)

func _update_chart(data: Dictionary) -> void:
	if not chart_panel or not chart_dock.visible:
		return
	
	## Get history data
	var time_history = data.get("time_history", [])
	var molecule_history = data.get("molecule_history", {})
	var enzyme_history = data.get("enzyme_history", {})
	
	## Build series data based on chart mode
	var series: Dictionary = {}
	
	match chart_mode:
		ChartMode.MOLECULES:
			for mol_name in molecule_history:
				series[mol_name] = molecule_history[mol_name]
		ChartMode.ENZYMES:
			for enz_id in enzyme_history:
				series[enz_id] = enzyme_history[enz_id]
		ChartMode.BOTH:
			for mol_name in molecule_history:
				series["mol:" + mol_name] = molecule_history[mol_name]
			for enz_id in enzyme_history:
				series["enz:" + enz_id] = enzyme_history[enz_id]
	
	## Create chart data dictionary
	var chart_data: Dictionary = {
		"time": time_history,
		"series": series
	}
	
	## Update chart
	var use_auto_scale = auto_scale_check.button_pressed if auto_scale_check else true
	chart_panel.update_chart(chart_data, use_auto_scale)

#endregion

#region UI Callbacks

func _on_pause_pressed() -> void:
	is_paused = not is_paused
	if sim_engine:
		sim_engine.set_paused(is_paused)
	if pause_button:
		pause_button.text = "▶ Resume" if is_paused else "⏸ Pause"

func _on_reset_pressed() -> void:
	if sim_engine:
		sim_engine.reset()
	_setup_panels()
	if chart_panel:
		chart_panel.clear()

func _on_speed_changed(value: float) -> void:
	if sim_engine:
		sim_engine.set_time_scale(value)
	if speed_value:
		speed_value.text = "%.1fx" % value

func _on_layout_selected(index: int) -> void:
	_apply_layout(index as LayoutMode)

func _on_view_menu_pressed(id: int) -> void:
	var popup = view_menu.get_popup()
	var idx = popup.get_item_index(id)
	var is_checked = popup.is_item_checked(idx)
	popup.set_item_checked(idx, not is_checked)
	
	var panel_names = ["cell", "reactions", "enzymes", "molecules", "genes", "chart"]
	if id < panel_names.size():
		panel_visibility[panel_names[id]] = not is_checked
		_update_dock_visibility(panel_names[id], not is_checked)

func _on_chart_mode_selected(index: int) -> void:
	chart_mode = index as ChartMode
	## Force chart redraw with new mode
	if sim_engine:
		var data = sim_engine.get_simulation_data()
		_update_chart(data)

func _on_auto_scale_toggled(_pressed: bool) -> void:
	## Force chart redraw
	if sim_engine:
		var data = sim_engine.get_simulation_data()
		_update_chart(data)

func _on_enzyme_concentration_changed(enzyme_id: String, value: float) -> void:
	if sim_engine:
		sim_engine.set_enzyme_concentration(enzyme_id, value)

func _on_enzyme_lock_changed(enzyme_id: String, locked: bool) -> void:
	if sim_engine and enzyme_id in sim_engine.enzymes:
		sim_engine.enzymes[enzyme_id].is_locked = locked

func _on_molecule_concentration_changed(mol_name: String, value: float) -> void:
	if sim_engine:
		sim_engine.set_molecule_concentration(mol_name, value)

func _on_molecule_lock_changed(mol_name: String, locked: bool) -> void:
	if sim_engine and mol_name in sim_engine.molecules:
		sim_engine.molecules[mol_name].is_locked = locked

#endregion

#region Panel Setup

func _setup_panels() -> void:
	if not sim_engine or not sim_engine.has_data():
		_show_empty_state()
		return
	
	if enzyme_panel:
		enzyme_panel.setup_items(sim_engine.enzymes.values(), "enzyme")
	
	if molecule_panel:
		molecule_panel.setup_items(sim_engine.molecules.values(), "molecule")
	
	if gene_panel and gene_panel.has_method("setup_genes"):
		gene_panel.setup_genes(sim_engine.genes, sim_engine.molecules, sim_engine.enzymes)

func _show_empty_state() -> void:
	if cell_content:
		cell_content.text = "[color=gray]No simulation loaded.\nSelect a pathway to begin.[/color]"
	if reactions_content:
		reactions_content.text = "[color=gray]No reactions[/color]"

#endregion

#region Layout Management

func _apply_layout(mode: LayoutMode) -> void:
	current_layout = mode
	
	match mode:
		LayoutMode.ALL_PANELS:
			_set_all_docks_visible(true)
		LayoutMode.FOCUS_CHART:
			_set_all_docks_visible(false)
			if chart_dock:
				chart_dock.visible = true
		LayoutMode.FOCUS_GENES:
			_set_all_docks_visible(false)
			if genes_dock:
				genes_dock.visible = true
		LayoutMode.TWO_COLUMN:
			_set_all_docks_visible(true)
			if left_column:
				left_column.visible = false
		LayoutMode.COMPACT:
			_set_all_docks_visible(false)
			if cell_dock:
				cell_dock.visible = true
			if chart_dock:
				chart_dock.visible = true

func _set_all_docks_visible(vis: bool) -> void:
	for dock in all_docks:
		if dock:
			dock.visible = vis

func _update_dock_visibility(panel_name: String, vis: bool) -> void:
	var dock_map = {
		"cell": cell_dock,
		"reactions": reactions_dock,
		"enzymes": enzymes_dock,
		"molecules": molecules_dock,
		"genes": genes_dock,
		"chart": chart_dock
	}
	
	if dock_map.has(panel_name) and dock_map[panel_name]:
		dock_map[panel_name].visible = vis

#endregion
