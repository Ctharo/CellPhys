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

#endregion

#region Initialization

func _ready() -> void:
	_setup_view_menu()
	_setup_isolate_menu()
	_cache_docks()
	_create_content_panels()
	
	await get_tree().process_frame
	
	_connect_signals()
	_connect_drag_drop_signals()
	_load_persistent_settings()
	_show_empty_state()
	_sync_lock_buttons()

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
	molecule_panel.set_panel_title("Molecules")
	if molecules_dock:
		molecules_dock.get_content_container().add_child(molecule_panel)
	
	## Genes
	gene_panel = GenePanel.new()
	if genes_dock:
		genes_dock.get_content_container().add_child(gene_panel)
	
	## Chart - assuming ChartPanel class exists
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
	
	## Lock button signals with persistence
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
	## Connect panel drop signals for inter-panel drops
	for dock in all_docks:
		if dock:
			dock.panel_dropped.connect(_on_panel_dropped)
	
	## Connect column drop signals
	for column in all_columns:
		if column:
			column.panel_dropped.connect(_on_column_panel_dropped)

func _load_persistent_settings() -> void:
	var settings = SettingsManager.get_instance()
	
	## Apply saved lock states to UI
	lock_molecules_btn.button_pressed = settings.lock_molecules
	lock_enzymes_btn.button_pressed = settings.lock_enzymes
	lock_genes_btn.button_pressed = settings.lock_genes
	lock_reactions_btn.button_pressed = settings.lock_reactions
	
	## Apply to simulation if available
	if sim_engine:
		sim_engine.lock_molecules = settings.lock_molecules
		sim_engine.lock_enzymes = settings.lock_enzymes
		sim_engine.lock_genes = settings.lock_genes
		sim_engine.lock_reactions = settings.lock_reactions
		sim_engine.lock_mutations = settings.lock_mutations

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

#region Public API

func set_simulator(simulator: Simulator) -> void:
	sim_engine = simulator
	
	if sim_engine:
		sim_engine.simulation_updated.connect(_on_simulation_updated)
		sim_engine.molecule_added.connect(_on_molecule_added)
		sim_engine.enzyme_added.connect(_on_enzyme_added)
		sim_engine.gene_added.connect(_on_gene_added)
		
		## Apply persistent settings to simulator
		var settings = SettingsManager.get_instance()
		sim_engine.lock_molecules = settings.lock_molecules
		sim_engine.lock_enzymes = settings.lock_enzymes
		sim_engine.lock_genes = settings.lock_genes
		sim_engine.lock_reactions = settings.lock_reactions
		sim_engine.lock_mutations = settings.lock_mutations
		
		_setup_panels()

func _setup_panels() -> void:
	if not sim_engine:
		return
	
	## Setup enzyme/reaction panel
	if enzyme_reaction_panel:
		enzyme_reaction_panel.setup_enzymes_and_reactions(
			sim_engine.enzymes.values(),
			sim_engine.reactions
		)
	
	## Setup molecule panel
	if molecule_panel:
		molecule_panel.setup_items(sim_engine.molecules.values(), "molecule")
	
	## Setup gene panel
	if gene_panel:
		gene_panel.setup_genes(sim_engine.genes, sim_engine.molecules, sim_engine.enzymes)

func _show_empty_state() -> void:
	if cell_content:
		cell_content.text = "[color=gray]No simulation loaded.\nSelect a pathway to begin.[/color]"

#endregion

#region Simulation Updates

func _on_simulation_updated(data: Dictionary) -> void:
	_update_cell_panel(data)
	_update_enzyme_reaction_panel(data)
	_update_molecules_panel(data)
	_update_genes_panel(data)
	_update_chart(data)

func _update_cell_panel(data: Dictionary) -> void:
	if not cell_content or not cell_dock.visible:
		return
	
	var cell = data.get("cell")
	if not cell:
		return
	
	var thermal = cell.get_thermal_status() if cell.has_method("get_thermal_status") else {}
	var energy = cell.get_energy_status() if cell.has_method("get_energy_status") else {}
	var protein = data.get("protein_stats", {})
	
	var text = ""
	var status_color = "green" if cell.is_alive else "red"
	var status_text = "ALIVE" if cell.is_alive else "DEAD"
	text += "[b]Status:[/b] [color=%s]%s[/color]\n" % [status_color, status_text]
	text += "[b]Time:[/b] %.1f s\n\n" % data.get("time", 0.0)
	
	text += "[color=yellow]━━ Thermal ━━[/color]\n"
	text += "Heat: %.1f / %.1f\n" % [thermal.get("heat", 0), thermal.get("max_threshold", 100)]
	text += "Generated: %.2f kJ\n\n" % energy.get("total_heat", 0)
	
	text += "[color=cyan]━━ Energy ━━[/color]\n"
	text += "Usable: %.2f kJ\n" % energy.get("usable_energy", 0)
	text += "Net: %.2f kJ\n\n" % energy.get("net_energy", 0)
	
	text += "[color=lime]━━ Proteins ━━[/color]\n"
	text += "Synth: %.4f mM\n" % protein.get("total_synthesized", 0.0)
	text += "Degrad: %.4f mM\n" % protein.get("total_degraded", 0.0)
	text += "↑%d ↓%d genes" % [protein.get("upregulated_genes", 0), protein.get("downregulated_genes", 0)]
	
	cell_content.text = text

func _update_enzyme_reaction_panel(data: Dictionary) -> void:
	if not enzyme_reaction_panel or not enzyme_reaction_dock.visible:
		return
	
	var enzymes: Dictionary = data.get("enzymes", {})
	var reactions: Array = data.get("reactions", [])
	enzyme_reaction_panel.update_values(enzymes.values(), reactions)

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
			var mol_hist = data.get("molecule_history", {})
			var enz_hist = data.get("enzyme_history", {})
			for key in mol_hist:
				combined["mol:" + key] = mol_hist[key]
			for key in enz_hist:
				combined["enz:" + key] = enz_hist[key]
			chart_data.series = combined
	
	if auto_scale_check:
		chart_panel.update_chart(chart_data, auto_scale_check.button_pressed)
	else:
		chart_panel.update_chart(chart_data, true)

#endregion

#region UI Callbacks

func _on_pause_pressed() -> void:
	if not sim_engine:
		return
	
	if not sim_engine.is_initialized:
		sim_engine.start_simulation()
	elif sim_engine.paused:
		sim_engine.set_paused(false)
		sim_engine.is_running = true
	else:
		sim_engine.set_paused(true)
		sim_engine.is_running = false
	
	is_paused = sim_engine.paused
	_update_pause_button()

func _on_reset_pressed() -> void:
	if not sim_engine:
		return
	
	sim_engine.reset()
	_show_empty_state()
	_update_pause_button()

func _on_speed_changed(value: float) -> void:
	if sim_engine:
		sim_engine.set_time_scale(value)
	speed_value.text = "%.1fx" % value

func _on_layout_selected(index: int) -> void:
	_apply_layout(index as LayoutMode)

func _on_chart_mode_selected(index: int) -> void:
	chart_mode = index as ChartMode

func _on_pathway_selected(index: int) -> void:
	if not sim_engine:
		return
	
	var pathway_names = ["linear", "feedback", "branched", "oscillator"]
	if index < pathway_names.size():
		sim_engine.load_builtin_pathway(pathway_names[index])
		_setup_panels()
		_update_pause_button()

func _on_isolate_selected(index: int) -> void:
	if not sim_engine:
		return
	
	match index:
		0:  ## Run All
			sim_engine.unlock_all()
		1:  ## Test Molecules
			sim_engine.isolate_system("molecules")
		2:  ## Test Enzymes
			sim_engine.isolate_system("enzymes")
		3:  ## Test Genes
			sim_engine.isolate_system("genes")
		4:  ## Test Reactions
			sim_engine.isolate_system("reactions")
		5:  ## Test Mutations
			sim_engine.isolate_system("mutations")
		6:  ## Lock All
			sim_engine.lock_all()
	
	_sync_lock_buttons()

func _update_pause_button() -> void:
	if not sim_engine or not sim_engine.is_initialized:
		pause_button.text = "▶ Start"
	elif sim_engine.paused:
		pause_button.text = "▶ Resume"
	else:
		pause_button.text = "⏸ Pause"

func _sync_lock_buttons() -> void:
	if not sim_engine:
		return
	
	lock_molecules_btn.button_pressed = sim_engine.lock_molecules
	lock_enzymes_btn.button_pressed = sim_engine.lock_enzymes
	lock_genes_btn.button_pressed = sim_engine.lock_genes
	lock_reactions_btn.button_pressed = sim_engine.lock_reactions

#endregion

#region Lock Callbacks with Persistence

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

#endregion

#region View Menu Callbacks

func _on_view_menu_pressed(id: int) -> void:
	var popup = view_menu.get_popup()
	
	match id:
		0: _toggle_panel("cell", popup, 0)
		1: _toggle_panel("enzyme_reaction", popup, 1)
		2: _toggle_panel("molecules", popup, 2)
		3: _toggle_panel("genes", popup, 3)
		4: _toggle_panel("chart", popup, 4)
		100:  ## Show All
			for i in range(5):
				popup.set_item_checked(i, true)
			for key in panel_visibility:
				panel_visibility[key] = true
			_apply_panel_visibility()
		101:  ## Hide All
			for i in range(5):
				popup.set_item_checked(i, false)
			for key in panel_visibility:
				panel_visibility[key] = false
			_apply_panel_visibility()

func _toggle_panel(panel_name_key: String, popup: PopupMenu, index: int) -> void:
	panel_visibility[panel_name_key] = not panel_visibility[panel_name_key]
	popup.set_item_checked(index, panel_visibility[panel_name_key])
	_apply_panel_visibility()

func _apply_panel_visibility() -> void:
	cell_dock.visible = panel_visibility["cell"]
	enzyme_reaction_dock.visible = panel_visibility["enzyme_reaction"]
	molecules_dock.visible = panel_visibility["molecules"]
	genes_dock.visible = panel_visibility["genes"]
	chart_dock.visible = panel_visibility["chart"]

func _on_panel_visibility_changed(pname: String, p_is_visible: bool) -> void:
	panel_visibility[pname] = p_is_visible
	var popup = view_menu.get_popup()
	var indices = {"cell": 0, "enzyme_reaction": 1, "molecules": 2, "genes": 3, "chart": 4}
	if indices.has(pname):
		popup.set_item_checked(indices[pname], p_is_visible)

#endregion

#region Drag and Drop Handling

func _on_panel_dropped(source: DockPanel, target_column: Control, at_index: int) -> void:
	_move_panel_to(source, target_column, at_index)

func _on_column_panel_dropped(panel: DockPanel, at_index: int) -> void:
	## Panel was dropped directly onto column, already handled by column
	pass

func _move_panel_to(panel: DockPanel, target_container: Control, target_index: int) -> void:
	var old_parent = panel.get_parent()
	
	## Remove from old parent
	if old_parent:
		old_parent.remove_child(panel)
	
	## Add to new container at specified index
	target_container.add_child(panel)
	if target_index >= 0 and target_index < target_container.get_child_count():
		target_container.move_child(panel, target_index)

#endregion

#region Entity Signal Handlers

func _on_molecule_added(molecule) -> void:
	if molecule_panel:
		molecule_panel.add_item(molecule, "molecule")

func _on_enzyme_added(enzyme) -> void:
	if enzyme_reaction_panel and sim_engine:
		var reactions_for_enzyme = sim_engine.reactions.filter(
			func(r): return r.enzyme_id == enzyme.enzyme_id if "enzyme_id" in r else false
		)
		enzyme_reaction_panel.add_enzyme(enzyme, reactions_for_enzyme)

func _on_gene_added(gene) -> void:
	if gene_panel and sim_engine:
		var enzyme = sim_engine.enzymes.get(gene.enzyme_id)
		gene_panel.add_gene(gene, enzyme)

#endregion

#region Concentration/Lock Callbacks

func _on_enzyme_concentration_changed(enzyme_id: String, value: float) -> void:
	if sim_engine and sim_engine.enzymes.has(enzyme_id):
		sim_engine.enzymes[enzyme_id].concentration = value

func _on_enzyme_lock_changed(enzyme_id: String, locked: bool) -> void:
	if sim_engine and sim_engine.enzymes.has(enzyme_id):
		sim_engine.enzymes[enzyme_id].is_locked = locked

func _on_molecule_concentration_changed(mol_id: String, value: float) -> void:
	if sim_engine and sim_engine.molecules.has(mol_id):
		sim_engine.molecules[mol_id].concentration = value

func _on_molecule_lock_changed(mol_id: String, locked: bool) -> void:
	if sim_engine and sim_engine.molecules.has(mol_id):
		sim_engine.molecules[mol_id].is_locked = locked

func _on_gene_toggled(enzyme_id: String, is_active: bool) -> void:
	if sim_engine and sim_engine.genes.has(enzyme_id):
		sim_engine.genes[enzyme_id].is_active = is_active

func _on_expression_rate_changed(enzyme_id: String, rate: float) -> void:
	if sim_engine and sim_engine.genes.has(enzyme_id):
		sim_engine.genes[enzyme_id].base_expression_rate = rate

#endregion

#region Layout Management

func _apply_layout(mode: LayoutMode) -> void:
	current_layout = mode
	
	## Remove all docks from current parents
	for dock in all_docks:
		if dock and dock.get_parent():
			dock.get_parent().remove_child(dock)
	
	## Clear containers
	for column in all_columns:
		if column:
			for child in column.get_children():
				if child is DockPanel:
					column.remove_child(child)
	
	## Rebuild based on layout mode
	match mode:
		LayoutMode.ALL_PANELS:
			left_column.add_child(cell_dock)
			middle_column.add_child(enzyme_reaction_dock)
			middle_column.add_child(molecules_dock)
			right_column.add_child(genes_dock)
			right_column.add_child(chart_dock)
			left_column.custom_minimum_size.x = 220
			middle_column.custom_minimum_size.x = 280
			right_column.custom_minimum_size.x = 280
		
		LayoutMode.FOCUS_CHART:
			left_column.add_child(enzyme_reaction_dock)
			left_column.add_child(molecules_dock)
			middle_column.add_child(cell_dock)
			middle_column.add_child(genes_dock)
			right_column.add_child(chart_dock)
			left_column.custom_minimum_size.x = 240
			middle_column.custom_minimum_size.x = 200
			right_column.custom_minimum_size.x = 350
		
		LayoutMode.COMPACT:
			left_column.add_child(cell_dock)
			left_column.add_child(chart_dock)
			middle_column.add_child(enzyme_reaction_dock)
			middle_column.add_child(molecules_dock)
			right_column.add_child(genes_dock)
			left_column.custom_minimum_size.x = 200
			middle_column.custom_minimum_size.x = 260
			right_column.custom_minimum_size.x = 240

func _on_window_resized() -> void:
	var window_width = get_viewport().get_visible_rect().size.x
	if window_width < 900 and current_layout != LayoutMode.COMPACT:
		layout_option.selected = LayoutMode.COMPACT
		_apply_layout(LayoutMode.COMPACT)
	elif window_width >= 900 and current_layout == LayoutMode.COMPACT:
		layout_option.selected = LayoutMode.ALL_PANELS
		_apply_layout(LayoutMode.ALL_PANELS)

#endregion
