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
	call_deferred("_setup_panels")
func _setup_view_menu() -> void:
	var popup = view_menu.get_popup()
	popup.clear()
	popup.add_check_item("Cell Status", 0)
	popup.add_check_item("Reactions", 1)
	popup.add_check_item("Enzymes", 2)
	popup.add_check_item("Molecules", 3)
	popup.add_check_item("Genes", 4)
	popup.add_check_item("Chart", 5)
	popup.add_separator()
	popup.add_item("Show All", 100)
	popup.add_item("Hide All", 101)
	
	for i in range(6):
		popup.set_item_checked(i, true)
	
	popup.id_pressed.connect(_on_view_menu_pressed)

func _cache_docks() -> void:
	all_docks = [cell_dock, reactions_dock, enzymes_dock, molecules_dock, genes_dock, chart_dock]

func _connect_signals() -> void:
	if sim_engine:
		sim_engine.simulation_updated.connect(_on_simulation_updated)
	
	get_tree().root.size_changed.connect(_on_window_resized)

func _setup_panels() -> void:
	if not sim_engine:
		return
	enzyme_panel.setup_items(sim_engine.enzymes.values(), "enzyme")
	molecule_panel.setup_items(sim_engine.molecules.values(), "molecule")
	gene_panel.setup_genes(sim_engine.genes, sim_engine.enzymes)

#endregion

#region Layout Management

func _apply_layout(mode: LayoutMode) -> void:
	current_layout = mode
	
	## Store references before reparenting
	var docks = {
		"cell": cell_dock,
		"reactions": reactions_dock,
		"enzymes": enzymes_dock,
		"molecules": molecules_dock,
		"genes": genes_dock,
		"chart": chart_dock
	}
	
	## Remove all docks from current parents
	for dock in all_docks:
		if dock.get_parent():
			dock.get_parent().remove_child(dock)
	
	## Clear containers
	for child in left_column.get_children():
		left_column.remove_child(child)
	for child in middle_column.get_children():
		middle_column.remove_child(child)
	for child in right_column.get_children():
		right_column.remove_child(child)
	
	## Rebuild based on layout mode
	match mode:
		LayoutMode.ALL_PANELS:
			left_column.add_child(cell_dock)
			left_column.add_child(reactions_dock)
			middle_column.add_child(enzymes_dock)
			middle_column.add_child(molecules_dock)
			right_column.add_child(genes_dock)
			right_column.add_child(chart_dock)
			left_column.custom_minimum_size.x = 220
			middle_column.custom_minimum_size.x = 240
			right_column.custom_minimum_size.x = 280
			right_column.size_flags_stretch_ratio = 1.3
		
		LayoutMode.FOCUS_CHART:
			left_column.add_child(enzymes_dock)
			left_column.add_child(molecules_dock)
			middle_column.add_child(cell_dock)
			middle_column.add_child(reactions_dock)
			right_column.add_child(chart_dock)
			right_column.add_child(genes_dock)
			left_column.custom_minimum_size.x = 200
			middle_column.custom_minimum_size.x = 200
			right_column.custom_minimum_size.x = 400
			right_column.size_flags_stretch_ratio = 2.0
		
		LayoutMode.FOCUS_GENES:
			left_column.add_child(genes_dock)
			middle_column.add_child(enzymes_dock)
			middle_column.add_child(molecules_dock)
			right_column.add_child(chart_dock)
			right_column.add_child(cell_dock)
			right_column.add_child(reactions_dock)
			left_column.custom_minimum_size.x = 350
			left_column.size_flags_stretch_ratio = 1.5
			middle_column.custom_minimum_size.x = 220
			right_column.custom_minimum_size.x = 280
			right_column.size_flags_stretch_ratio = 1.0
		
		LayoutMode.TWO_COLUMN:
			left_column.add_child(cell_dock)
			left_column.add_child(reactions_dock)
			left_column.add_child(genes_dock)
			middle_column.add_child(enzymes_dock)
			middle_column.add_child(molecules_dock)
			right_column.add_child(chart_dock)
			left_column.custom_minimum_size.x = 250
			middle_column.custom_minimum_size.x = 250
			right_column.custom_minimum_size.x = 350
			right_column.size_flags_stretch_ratio = 1.5
		
		LayoutMode.COMPACT:
			## Stack everything vertically
			left_column.add_child(chart_dock)
			left_column.add_child(genes_dock)
			middle_column.add_child(enzymes_dock)
			middle_column.add_child(molecules_dock)
			right_column.add_child(cell_dock)
			right_column.add_child(reactions_dock)
			left_column.custom_minimum_size.x = 200
			middle_column.custom_minimum_size.x = 200
			right_column.custom_minimum_size.x = 200
			right_column.size_flags_stretch_ratio = 1.0
	
	_apply_panel_visibility()

func _apply_panel_visibility() -> void:
	cell_dock.visible = panel_visibility["cell"]
	reactions_dock.visible = panel_visibility["reactions"]
	enzymes_dock.visible = panel_visibility["enzymes"]
	molecules_dock.visible = panel_visibility["molecules"]
	genes_dock.visible = panel_visibility["genes"]
	chart_dock.visible = panel_visibility["chart"]

func _on_window_resized() -> void:
	var window_width = get_viewport().get_visible_rect().size.x
	if window_width < 900 and current_layout != LayoutMode.COMPACT:
		layout_option.selected = LayoutMode.COMPACT
		_apply_layout(LayoutMode.COMPACT)
	elif window_width >= 900 and current_layout == LayoutMode.COMPACT:
		layout_option.selected = LayoutMode.ALL_PANELS
		_apply_layout(LayoutMode.ALL_PANELS)

#endregion

#region Simulation Updates

func _on_simulation_updated(data: Dictionary) -> void:
	_update_cell_panel(data)
	_update_reactions_panel(data)
	_update_enzymes_panel(data)
	_update_molecules_panel(data)
	_update_genes_panel(data)
	_update_chart(data)

func _update_cell_panel(data: Dictionary) -> void:
	if not cell_content or not cell_dock.visible:
		return
	
	var cell: Cell = data.get("cell")
	if not cell:
		return
	
	var thermal = cell.get_thermal_status()
	var energy = cell.get_energy_status()
	var protein = data.get("protein_stats", {})
	
	var text = ""
	var status_color = "green" if cell.is_alive else "red"
	var status_text = "ALIVE" if cell.is_alive else "DEAD"
	text += "[b]Status:[/b] [color=%s]%s[/color]\n" % [status_color, status_text]
	text += "[b]Time:[/b] %.1f s\n\n" % data.get("time", 0.0)
	
	text += "[color=yellow]━━ Thermal ━━[/color]\n"
	text += "Heat: %.1f / %.1f\n" % [thermal.heat, thermal.max_threshold]
	text += "Generated: %.2f kJ\n\n" % energy.total_heat
	
	text += "[color=cyan]━━ Energy ━━[/color]\n"
	text += "Usable: %.2f kJ\n" % energy.usable_energy
	text += "Net: %.2f kJ\n\n" % energy.net_energy
	
	text += "[color=lime]━━ Proteins ━━[/color]\n"
	text += "Synth: %.4f mM\n" % protein.get("total_synthesized", 0.0)
	text += "Degrad: %.4f mM\n" % protein.get("total_degraded", 0.0)
	text += "↑%d ↓%d genes" % [protein.get("upregulated_genes", 0), protein.get("downregulated_genes", 0)]
	
	cell_content.text = text

func _update_reactions_panel(data: Dictionary) -> void:
	if not reactions_content or not reactions_dock.visible:
		return
	
	var reactions: Array = data.get("reactions", [])
	var text = ""
	
	for rxn in reactions:
		var net_rate = rxn.get_net_rate()
		var rate_color = "lime" if net_rate > 0.001 else ("orange" if net_rate < -0.001 else "gray")
		
		text += "[b]%s[/b]\n" % rxn.get_summary()
		text += "  η=%.0f%% ΔG=%.1f kJ/mol\n" % [rxn.reaction_efficiency * 100.0, rxn.current_delta_g_actual]
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
	
	var chart_data: Dictionary = {
		"time": data.get("time_history", []),
		"series": {}
	}
	
	match chart_mode:
		ChartMode.MOLECULES:
			chart_data.series = data.get("molecule_history", {})
		ChartMode.ENZYMES:
			chart_data.series = data.get("enzyme_history", {})
		ChartMode.BOTH:
			var combined = {}
			for key in data.get("molecule_history", {}):
				combined["mol:" + key] = data.molecule_history[key]
			for key in data.get("enzyme_history", {}):
				combined["enz:" + key] = data.enzyme_history[key]
			chart_data.series = combined
	
	chart_panel.update_chart(chart_data, auto_scale_check.button_pressed)

#endregion

#region UI Callbacks

func _on_pause_pressed() -> void:
	is_paused = not is_paused
	sim_engine.set_paused(is_paused)
	pause_button.text = "▶ Resume" if is_paused else "⏸ Pause"

func _on_reset_pressed() -> void:
	sim_engine.reset()
	_setup_panels()

func _on_speed_changed(value: float) -> void:
	sim_engine.set_time_scale(value)
	speed_value.text = "%.1fx" % value

func _on_layout_selected(index: int) -> void:
	_apply_layout(index as LayoutMode)

func _on_view_menu_pressed(id: int) -> void:
	var popup = view_menu.get_popup()
	
	match id:
		0: _toggle_panel("cell", popup, 0)
		1: _toggle_panel("reactions", popup, 1)
		2: _toggle_panel("enzymes", popup, 2)
		3: _toggle_panel("molecules", popup, 3)
		4: _toggle_panel("genes", popup, 4)
		5: _toggle_panel("chart", popup, 5)
		100:  ## Show All
			for i in range(6):
				popup.set_item_checked(i, true)
			for key in panel_visibility:
				panel_visibility[key] = true
			_apply_panel_visibility()
		101:  ## Hide All
			for i in range(6):
				popup.set_item_checked(i, false)
			for key in panel_visibility:
				panel_visibility[key] = false
			_apply_panel_visibility()

func _toggle_panel(panel_name: String, popup: PopupMenu, index: int) -> void:
	panel_visibility[panel_name] = not panel_visibility[panel_name]
	popup.set_item_checked(index, panel_visibility[panel_name])
	_apply_panel_visibility()

func _on_panel_visibility_changed(panel_name: String, is_visible: bool) -> void:
	panel_visibility[panel_name] = is_visible
	var popup = view_menu.get_popup()
	var indices = {"cell": 0, "reactions": 1, "enzymes": 2, "molecules": 3, "genes": 4, "chart": 5}
	if indices.has(panel_name):
		popup.set_item_checked(indices[panel_name], is_visible)

func _on_chart_mode_changed(index: int) -> void:
	chart_mode = index as ChartMode

func _on_auto_scale_toggled(_pressed: bool) -> void:
	pass

func _on_enzyme_concentration_changed(id: String, value: float) -> void:
	if sim_engine and sim_engine.enzymes.has(id):
		sim_engine.enzymes[id].concentration = value

func _on_enzyme_lock_changed(id: String, locked: bool) -> void:
	if sim_engine and sim_engine.enzymes.has(id):
		sim_engine.enzymes[id].is_locked = locked

func _on_molecule_concentration_changed(mol_name: String, value: float) -> void:
	if sim_engine and sim_engine.molecules.has(mol_name):
		sim_engine.molecules[mol_name].concentration = value

func _on_molecule_lock_changed(mol_name: String, locked: bool) -> void:
	if sim_engine and sim_engine.molecules.has(mol_name):
		sim_engine.molecules[mol_name].is_locked = locked

func _on_gene_toggled(gene_id: String, is_active: bool) -> void:
	if sim_engine and sim_engine.genes.has(gene_id):
		sim_engine.genes[gene_id].is_active = is_active

#endregion
