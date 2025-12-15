## Main UI controller for biochemistry simulator
## Integrates combined enzyme/reaction panels, persistent settings, and drag-drop
extends Control

#region Enums

enum LayoutMode { ALL_PANELS, FOCUS_CHART, COMPACT }
enum ChartMode { MOLECULES, ENZYMES, BOTH }

#endregion

#region Node References - Toolbar

@onready var pause_button: Button = %PauseButton
@onready var reset_button: Button = %ResetButton
@onready var pathway_option: OptionButton = %PathwayOption
@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_value: Label = %SpeedValue
@onready var layout_option: OptionButton = %LayoutOption
@onready var view_menu: MenuButton = %ViewMenu
@onready var auto_scale_check: CheckBox = %AutoScaleCheck
@onready var chart_mode_option: OptionButton = %ChartModeOption

## Test Controls
@onready var isolate_option: OptionButton = %IsolateOption
@onready var lock_molecules_btn: CheckButton = %LockMoleculesBtn
@onready var lock_enzymes_btn: CheckButton = %LockEnzymesBtn
@onready var lock_genes_btn: CheckButton = %LockGenesBtn
@onready var lock_reactions_btn: CheckButton = %LockReactionsBtn

## Save/Load buttons (optional - may not exist in scene)
var save_button: Button = null
var load_button: Button = null

#endregion

#region Node References - Layout

@onready var left_column: DraggableColumn = %LeftColumn
@onready var middle_column: DraggableColumn = %MiddleColumn
@onready var right_column: DraggableColumn = %RightColumn

## Dock panels
@onready var cell_dock: DockPanel = %CellPanel
@onready var enzyme_reaction_dock: DockPanel = %EnzymeReactionPanel
@onready var molecules_dock: DockPanel = %MoleculesPanel
@onready var genes_dock: DockPanel = %GenesPanel
@onready var chart_dock: DockPanel = %ChartDock

## Content panels
var cell_content: RichTextLabel = null
var enzyme_reaction_panel: EnzymeReactionPanel = null
var molecule_panel: ConcentrationPanel = null
var gene_panel: GenePanel = null
var chart_panel: ChartPanel = null

#endregion

#region Simulation Reference

var sim_engine: Simulator = null

#endregion

#region State

var current_layout: LayoutMode = LayoutMode.ALL_PANELS
var chart_mode: ChartMode = ChartMode.MOLECULES
var is_paused: bool = true

var panel_visibility: Dictionary = {
	"cell": true,
	"enzyme_reaction": true,
	"molecules": true,
	"genes": true,
	"chart": true
}

var all_docks: Array[DockPanel] = []
var all_columns: Array[DraggableColumn] = []

## Pathway name mapping for dropdown
const PATHWAY_NAMES: Array[String] = [
	"default",
	"glycolysis", 
	"krebs",
	"pentose_phosphate",
	"beta_oxidation",
	"urea"
]

const PATHWAY_DISPLAY_NAMES: Array[String] = [
	"Default Linear",
	"Glycolysis",
	"Krebs Cycle (TCA)",
	"Pentose Phosphate",
	"β-Oxidation",
	"Urea Cycle"
]

#endregion

#region Initialization

func _ready() -> void:
	_setup_pathway_options()
	_setup_view_menu()
	_setup_isolate_menu()
	_cache_docks()
	_create_content_panels()
	_create_simulator()
	_create_save_load_buttons()
	
	await get_tree().process_frame
	
	_connect_signals()
	_connect_drag_drop_signals()
	_load_persistent_settings()
	_restore_layout()
	_show_empty_state()
	_sync_lock_buttons()


func _setup_pathway_options() -> void:
	if not pathway_option:
		return
	
	pathway_option.clear()
	for i in range(PATHWAY_DISPLAY_NAMES.size()):
		pathway_option.add_item(PATHWAY_DISPLAY_NAMES[i], i)
	
	## Add separator and browser option
	pathway_option.add_separator()
	pathway_option.add_item("Browse All...", 100)


func _create_simulator() -> void:
	sim_engine = Simulator.new()
	sim_engine.name = "Simulator"
	sim_engine.auto_generate = false
	add_child(sim_engine)
	
	## Connect simulator signals
	sim_engine.simulation_updated.connect(_on_simulation_updated)
	sim_engine.simulation_started.connect(_on_simulation_started)
	sim_engine.simulation_stopped.connect(_on_simulation_stopped)
	sim_engine.enzyme_added.connect(_on_enzyme_added)
	sim_engine.gene_added.connect(_on_gene_added)
	sim_engine.pathway_loaded.connect(_on_pathway_loaded)
	sim_engine.snapshot_loaded.connect(_on_snapshot_loaded)


func _create_save_load_buttons() -> void:
	## Find toolbar HBox to add save/load buttons
	var toolbar_hbox = pause_button.get_parent() if pause_button else null
	if not toolbar_hbox:
		return
	
	## Add separator
	var sep = VSeparator.new()
	toolbar_hbox.add_child(sep)
	toolbar_hbox.move_child(sep, -1)
	
	## Save button
	save_button = Button.new()
	save_button.text = "💾 Save"
	save_button.pressed.connect(_on_save_pressed)
	toolbar_hbox.add_child(save_button)
	
	## Load button
	load_button = Button.new()
	load_button.text = "📂 Load"
	load_button.pressed.connect(_on_load_pressed)
	toolbar_hbox.add_child(load_button)


func _cache_docks() -> void:
	all_docks = [cell_dock, enzyme_reaction_dock, molecules_dock, genes_dock, chart_dock]
	all_columns = [left_column, middle_column, right_column]


func _create_content_panels() -> void:
	## Cell status - RichTextLabel
	cell_content = RichTextLabel.new()
	cell_content.bbcode_enabled = true
	cell_content.fit_content = true
	cell_content.scroll_active = false
	if cell_dock:
		cell_dock.get_content_container().add_child(cell_content)
	
	## Combined enzyme/reaction panel
	enzyme_reaction_panel = EnzymeReactionPanel.new()
	if enzyme_reaction_dock:
		enzyme_reaction_dock.get_content_container().add_child(enzyme_reaction_panel)
	
	## Molecule concentrations
	molecule_panel = ConcentrationPanel.new()
	if molecules_dock:
		molecules_dock.get_content_container().add_child(molecule_panel)
	
	## Genes
	gene_panel = GenePanel.new()
	if genes_dock:
		genes_dock.get_content_container().add_child(gene_panel)
	
	## Chart
	chart_panel = ChartPanel.new() if ClassDB.class_exists("ChartPanel") else null
	if chart_panel and chart_dock:
		chart_dock.get_content_container().add_child(chart_panel)


func _connect_signals() -> void:
	## Toolbar signals
	pause_button.pressed.connect(_on_pause_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	speed_slider.value_changed.connect(_on_speed_changed)
	layout_option.item_selected.connect(_on_layout_selected)
	view_menu.get_popup().id_pressed.connect(_on_view_menu_pressed)
	chart_mode_option.item_selected.connect(_on_chart_mode_selected)
	pathway_option.item_selected.connect(_on_pathway_selected)
	isolate_option.item_selected.connect(_on_isolate_selected)
	
	## Lock button signals
	lock_molecules_btn.toggled.connect(_on_lock_molecules_toggled)
	lock_enzymes_btn.toggled.connect(_on_lock_enzymes_toggled)
	lock_genes_btn.toggled.connect(_on_lock_genes_toggled)
	lock_reactions_btn.toggled.connect(_on_lock_reactions_toggled)
	
	## Panel signals
	if enzyme_reaction_panel:
		enzyme_reaction_panel.concentration_changed.connect(_on_enzyme_concentration_changed)
		enzyme_reaction_panel.lock_changed.connect(_on_enzyme_lock_changed)
	
	if molecule_panel:
		molecule_panel.concentration_changed.connect(_on_molecule_concentration_changed)
		molecule_panel.lock_changed.connect(_on_molecule_lock_changed)
	
	if gene_panel:
		gene_panel.gene_toggled.connect(_on_gene_toggled)
		gene_panel.expression_rate_changed.connect(_on_expression_rate_changed)
	
	## Dock visibility signals
	for dock in all_docks:
		if dock:
			dock.panel_visibility_changed.connect(_on_panel_visibility_changed)
	
	## Window resize
	get_tree().root.size_changed.connect(_on_window_resized)


func _connect_drag_drop_signals() -> void:
	for column in all_columns:
		if column:
			column.panel_dropped.connect(_on_panel_dropped)

#endregion

#region Pathway Selection

func _on_pathway_selected(index: int) -> void:
	var item_id = pathway_option.get_item_id(index)
	
	## Browse All option
	if item_id == 100:
		_show_pathway_browser()
		return
	
	## Load builtin pathway
	if item_id >= 0 and item_id < PATHWAY_NAMES.size():
		var pathway_name = PATHWAY_NAMES[item_id]
		sim_engine.load_builtin_pathway(pathway_name)


func _show_pathway_browser() -> void:
	var browser = PathwayBrowser.new()
	browser.pathway_selected.connect(_on_browser_pathway_selected)
	browser.snapshot_selected.connect(_on_browser_snapshot_selected)
	add_child(browser)
	browser.popup_centered()


func _on_browser_pathway_selected(preset: PathwayPreset) -> void:
	sim_engine.load_pathway(preset)


func _on_browser_snapshot_selected(snapshot: SimulationSnapshot) -> void:
	snapshot.restore_to(sim_engine)
	_setup_panels()
	_update_pathway_dropdown_to_custom()


func _on_pathway_loaded(preset: PathwayPreset) -> void:
	_setup_panels()
	_update_pause_button()
	
	## Try to find matching dropdown item
	var found = false
	for i in range(PATHWAY_NAMES.size()):
		if preset.pathway_name.to_lower().contains(PATHWAY_NAMES[i]):
			pathway_option.select(i)
			found = true
			break
	
	if not found:
		_update_pathway_dropdown_to_custom()


func _on_snapshot_loaded(_path: String) -> void:
	_setup_panels()
	_update_pause_button()
	_update_pathway_dropdown_to_custom()


func _update_pathway_dropdown_to_custom() -> void:
	## Add "Custom" option if not present
	var custom_idx = -1
	for i in range(pathway_option.item_count):
		if pathway_option.get_item_text(i) == "Custom":
			custom_idx = i
			break
	
	if custom_idx < 0:
		pathway_option.add_item("Custom", 99)
		custom_idx = pathway_option.item_count - 1
	
	pathway_option.select(custom_idx)

#endregion

#region Save/Load

func _on_save_pressed() -> void:
	if not sim_engine or not sim_engine.has_data():
		return
	
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path = "user://snapshots/sim_%s.tres" % timestamp
	
	## Ensure directory exists
	DirAccess.make_dir_recursive_absolute("user://snapshots")
	
	var err = sim_engine.save_snapshot(path, "Snapshot %s" % timestamp)
	if err == OK:
		print("Saved simulation to: ", path)
	else:
		push_error("Failed to save simulation: %d" % err)


func _on_load_pressed() -> void:
	_show_pathway_browser()

#endregion

#region Simulation Control

func _on_pause_pressed() -> void:
	if not sim_engine:
		return
	
	if sim_engine.paused:
		sim_engine.start_simulation()
	else:
		sim_engine.stop_simulation()
	
	_update_pause_button()


func _on_reset_pressed() -> void:
	if not sim_engine:
		return
	
	## Reload current pathway
	var current_idx = pathway_option.selected
	if current_idx >= 0 and current_idx < PATHWAY_NAMES.size():
		sim_engine.load_builtin_pathway(PATHWAY_NAMES[current_idx])
	else:
		sim_engine.reset()
		_show_empty_state()
	
	_update_pause_button()


func _on_speed_changed(value: float) -> void:
	if sim_engine:
		sim_engine.time_scale = value
	if speed_value:
		speed_value.text = "%.1fx" % value


func _update_pause_button() -> void:
	if not pause_button or not sim_engine:
		return
	
	if sim_engine.paused:
		pause_button.text = "▶ Start"
	else:
		pause_button.text = "⏸ Pause"
	
	is_paused = sim_engine.paused


func _on_simulation_started() -> void:
	_update_pause_button()


func _on_simulation_stopped() -> void:
	_update_pause_button()

#endregion

#region Simulation Updates

func _on_simulation_updated(data: Dictionary) -> void:
	_update_cell_display(data)
	_update_panels(data)
	_update_chart(data)


func _update_cell_display(data: Dictionary) -> void:
	if not cell_content:
		return
	
	var cell = data.get("cell")
	if not cell:
		return
	
	var text = "[b]Cell Status[/b]\n"
	text += "Time: %.1f s\n" % data.get("time", 0.0)
	text += "Temperature: %.1f K (%.1f°C)\n" % [cell.temperature, cell.temperature - 273.15]
	text += "Heat: %.2f kJ\n" % cell.heat
	text += "Usable Energy: %.2f kJ\n" % cell.usable_energy
	
	var status_color = "green" if cell.is_alive else "red"
	text += "Status: [color=%s]%s[/color]\n" % [status_color, "Alive" if cell.is_alive else "Dead"]
	
	## Protein stats
	var stats = data.get("protein_stats", {})
	if not stats.is_empty():
		text += "\n[b]Protein Expression[/b]\n"
		text += "Synthesized: %.4f mM\n" % stats.get("total_synthesized", 0.0)
		text += "Degraded: %.4f mM\n" % stats.get("total_degraded", 0.0)
		text += "Active genes: %d\n" % stats.get("active_genes", 0)
	
	cell_content.text = text


func _update_panels(data: Dictionary) -> void:
	if enzyme_reaction_panel:
		enzyme_reaction_panel.update_values(
			data.get("enzymes", {}).values(),
			data.get("reactions", [])
		)
	
	if molecule_panel:
		molecule_panel.update_values(data.get("molecules", {}).values())
	
	if gene_panel:
		gene_panel.update_values(data.get("genes", {}), data.get("molecules", {}))


func _update_chart(data: Dictionary) -> void:
	if not chart_panel:
		return
	
	match chart_mode:
		ChartMode.MOLECULES:
			chart_panel.update_data(
				data.get("time_history", []),
				data.get("molecule_history", {}),
				"Molecule Concentrations (mM)"
			)
		ChartMode.ENZYMES:
			chart_panel.update_data(
				data.get("time_history", []),
				data.get("enzyme_history", {}),
				"Enzyme Concentrations (mM)"
			)
		ChartMode.BOTH:
			var combined = {}
			combined.merge(data.get("molecule_history", {}))
			combined.merge(data.get("enzyme_history", {}))
			chart_panel.update_data(
				data.get("time_history", []),
				combined,
				"All Concentrations (mM)"
			)

#endregion

#region Panel Setup

func _setup_panels() -> void:
	if not sim_engine or not sim_engine.has_data():
		return
	
	if enzyme_reaction_panel:
		enzyme_reaction_panel.setup_enzymes_and_reactions(
			sim_engine.enzymes.values(),
			sim_engine.reactions
		)
	
	if molecule_panel:
		molecule_panel.setup_items(sim_engine.molecules.values(), "molecule")
	
	if gene_panel:
		gene_panel.setup_genes(sim_engine.genes, sim_engine.molecules, sim_engine.enzymes)


func _show_empty_state() -> void:
	if cell_content:
		cell_content.text = "[color=gray]No simulation loaded.\nSelect a pathway to begin.[/color]"

#endregion

#region Lock Controls

func _on_lock_molecules_toggled(pressed: bool) -> void:
	if sim_engine:
		sim_engine.lock_molecules = pressed
	SettingsManager.get_instance().set_lock_molecules(pressed)


func _on_lock_enzymes_toggled(pressed: bool) -> void:
	if sim_engine:
		sim_engine.lock_enzymes = pressed
	SettingsManager.get_instance().set_lock_enzymes(pressed)


func _on_lock_genes_toggled(pressed: bool) -> void:
	if sim_engine:
		sim_engine.lock_genes = pressed
	SettingsManager.get_instance().set_lock_genes(pressed)


func _on_lock_reactions_toggled(pressed: bool) -> void:
	if sim_engine:
		sim_engine.lock_reactions = pressed
	SettingsManager.get_instance().set_lock_reactions(pressed)


func _sync_lock_buttons() -> void:
	if not sim_engine:
		return
	
	if lock_molecules_btn:
		lock_molecules_btn.button_pressed = sim_engine.lock_molecules
	if lock_enzymes_btn:
		lock_enzymes_btn.button_pressed = sim_engine.lock_enzymes
	if lock_genes_btn:
		lock_genes_btn.button_pressed = sim_engine.lock_genes
	if lock_reactions_btn:
		lock_reactions_btn.button_pressed = sim_engine.lock_reactions


func _on_isolate_selected(index: int) -> void:
	if not sim_engine:
		return
	
	var settings = SettingsManager.get_instance()
	
	match index:
		0:  ## Run All
			sim_engine.lock_molecules = false
			sim_engine.lock_enzymes = false
			sim_engine.lock_genes = false
			sim_engine.lock_reactions = false
			sim_engine.lock_mutations = true
		1:  ## Test Molecules
			sim_engine.lock_molecules = false
			sim_engine.lock_enzymes = true
			sim_engine.lock_genes = true
			sim_engine.lock_reactions = true
			sim_engine.lock_mutations = true
		2:  ## Test Enzymes
			sim_engine.lock_molecules = true
			sim_engine.lock_enzymes = false
			sim_engine.lock_genes = true
			sim_engine.lock_reactions = true
			sim_engine.lock_mutations = true
		3:  ## Test Genes
			sim_engine.lock_molecules = true
			sim_engine.lock_enzymes = true
			sim_engine.lock_genes = false
			sim_engine.lock_reactions = true
			sim_engine.lock_mutations = true
		4:  ## Test Reactions
			sim_engine.lock_molecules = true
			sim_engine.lock_enzymes = true
			sim_engine.lock_genes = true
			sim_engine.lock_reactions = false
			sim_engine.lock_mutations = true
		5:  ## Test Mutations
			sim_engine.lock_molecules = true
			sim_engine.lock_enzymes = true
			sim_engine.lock_genes = true
			sim_engine.lock_reactions = true
			sim_engine.lock_mutations = false
		6:  ## Lock All
			sim_engine.lock_molecules = true
			sim_engine.lock_enzymes = true
			sim_engine.lock_genes = true
			sim_engine.lock_reactions = true
			sim_engine.lock_mutations = true
	
	## Save to settings
	settings.set_lock_molecules(sim_engine.lock_molecules)
	settings.set_lock_enzymes(sim_engine.lock_enzymes)
	settings.set_lock_genes(sim_engine.lock_genes)
	settings.set_lock_reactions(sim_engine.lock_reactions)
	settings.set_lock_mutations(sim_engine.lock_mutations)
	
	_sync_lock_buttons()

#endregion

#region Panel Callbacks

func _on_enzyme_concentration_changed(enzyme_id: String, new_conc: float) -> void:
	if sim_engine and sim_engine.enzymes.has(enzyme_id):
		sim_engine.enzymes[enzyme_id].concentration = new_conc


func _on_enzyme_lock_changed(enzyme_id: String, locked: bool) -> void:
	if sim_engine and sim_engine.enzymes.has(enzyme_id):
		sim_engine.enzymes[enzyme_id].is_locked = locked


func _on_molecule_concentration_changed(mol_name: String, new_conc: float) -> void:
	if sim_engine and sim_engine.molecules.has(mol_name):
		sim_engine.molecules[mol_name].concentration = new_conc


func _on_molecule_lock_changed(mol_name: String, locked: bool) -> void:
	if sim_engine and sim_engine.molecules.has(mol_name):
		sim_engine.molecules[mol_name].is_locked = locked


func _on_gene_toggled(gene_id: String, active: bool) -> void:
	if sim_engine and sim_engine.genes.has(gene_id):
		sim_engine.genes[gene_id].is_active = active


func _on_expression_rate_changed(gene_id: String, new_rate: float) -> void:
	if sim_engine and sim_engine.genes.has(gene_id):
		sim_engine.genes[gene_id].basal_rate = new_rate


func _on_enzyme_added(_enzyme: EnzymeData) -> void:
	_setup_panels()


func _on_gene_added(_gene: GeneData) -> void:
	_setup_panels()

#endregion

#region View Menu

func _setup_view_menu() -> void:
	var popup = view_menu.get_popup()
	popup.clear()
	
	popup.add_check_item("Cell Status", 0)
	popup.add_check_item("Enzymes & Reactions", 1)
	popup.add_check_item("Molecules", 2)
	popup.add_check_item("Genes", 3)
	popup.add_check_item("Chart", 4)
	popup.add_separator()
	popup.add_item("Show All", 100)
	popup.add_item("Hide All", 101)
	
	for i in range(5):
		popup.set_item_checked(i, true)


func _on_view_menu_pressed(id: int) -> void:
	var popup = view_menu.get_popup()
	
	match id:
		100:  ## Show All
			for i in range(5):
				popup.set_item_checked(i, true)
			_apply_panel_visibility()
		101:  ## Hide All
			for i in range(5):
				popup.set_item_checked(i, false)
			_apply_panel_visibility()
		_:
			if id < 5:
				var checked = popup.is_item_checked(id)
				popup.set_item_checked(id, not checked)
				_apply_panel_visibility()


func _apply_panel_visibility() -> void:
	var popup = view_menu.get_popup()
	
	if cell_dock:
		cell_dock.visible = popup.is_item_checked(0)
	if enzyme_reaction_dock:
		enzyme_reaction_dock.visible = popup.is_item_checked(1)
	if molecules_dock:
		molecules_dock.visible = popup.is_item_checked(2)
	if genes_dock:
		genes_dock.visible = popup.is_item_checked(3)
	if chart_dock:
		chart_dock.visible = popup.is_item_checked(4)


func _on_panel_visibility_changed(panel_name: String, visible: bool) -> void:
	panel_visibility[panel_name] = visible

#endregion

#region Isolate Menu

func _setup_isolate_menu() -> void:
	if not isolate_option:
		return
	isolate_option.clear()
	isolate_option.add_item("Run All", 0)
	isolate_option.add_item("Test Molecules", 1)
	isolate_option.add_item("Test Enzymes", 2)
	isolate_option.add_item("Test Genes", 3)
	isolate_option.add_item("Test Reactions", 4)
	isolate_option.add_item("Test Mutations", 5)
	isolate_option.add_item("Lock All", 6)

#endregion

#region Layout

func _on_layout_selected(index: int) -> void:
	current_layout = index as LayoutMode
	_apply_layout()
	SettingsManager.get_instance().set_layout_mode(index)


func _apply_layout() -> void:
	## Reset visibility
	for dock in all_docks:
		if dock:
			dock.visible = true
	
	match current_layout:
		LayoutMode.FOCUS_CHART:
			if cell_dock:
				cell_dock.visible = false
			if enzyme_reaction_dock:
				enzyme_reaction_dock.visible = false
		LayoutMode.COMPACT:
			if genes_dock:
				genes_dock.visible = false


func _on_chart_mode_selected(index: int) -> void:
	chart_mode = index as ChartMode

#endregion

#region Drag and Drop

func _on_panel_dropped(panel: DockPanel, _target_column: DraggableColumn) -> void:
	_save_current_layout()
	print("Panel dropped: ", panel.panel_name)


func _restore_layout() -> void:
	var settings = SettingsManager.get_instance()
	if not settings:
		return
	
	## Check if we have any saved positions
	if settings.panel_positions.is_empty():
		return
	
	var column_panels: Array[Array] = [[], [], []]
	
	for dock in all_docks:
		if not dock:
			continue
		var pos = settings.get_panel_position(dock.panel_name)
		if pos.is_empty():
			## No saved position, default to column 0
			column_panels[0].append({"dock": dock, "order": 999})
		else:
			var col_idx = clampi(pos.get("column", 0), 0, 2)
			column_panels[col_idx].append({"dock": dock, "order": pos.get("order", 0)})
	
	## Remove docks from current parents first
	for dock in all_docks:
		if dock and dock.get_parent():
			dock.get_parent().remove_child(dock)
	
	## Sort and add to columns
	for col_idx in range(column_panels.size()):
		column_panels[col_idx].sort_custom(func(a, b): return a.order < b.order)
		for item in column_panels[col_idx]:
			all_columns[col_idx].add_child(item.dock)


func _save_current_layout() -> void:
	var settings = SettingsManager.get_instance()
	if not settings:
		return
	
	for col_idx in range(all_columns.size()):
		var column = all_columns[col_idx]
		var order = 0
		for child in column.get_children():
			if child is DockPanel:
				settings.set_panel_position(child.panel_name, col_idx, order)
				order += 1


func _load_persistent_settings() -> void:
	var settings = SettingsManager.get_instance()
	if not settings:
		return
	
	## Apply saved lock states to UI
	if lock_molecules_btn:
		lock_molecules_btn.set_pressed_no_signal(settings.lock_molecules)
	if lock_enzymes_btn:
		lock_enzymes_btn.set_pressed_no_signal(settings.lock_enzymes)
	if lock_genes_btn:
		lock_genes_btn.set_pressed_no_signal(settings.lock_genes)
	if lock_reactions_btn:
		lock_reactions_btn.set_pressed_no_signal(settings.lock_reactions)
	
	## Apply saved layout mode
	if layout_option:
		layout_option.selected = settings.layout_mode
	
	## Apply to simulation if available
	if sim_engine:
		sim_engine.lock_molecules = settings.lock_molecules
		sim_engine.lock_enzymes = settings.lock_enzymes
		sim_engine.lock_genes = settings.lock_genes
		sim_engine.lock_reactions = settings.lock_reactions
		sim_engine.lock_mutations = settings.lock_mutations


func _on_window_resized() -> void:
	## Handle window resize if needed
	pass

#endregion
