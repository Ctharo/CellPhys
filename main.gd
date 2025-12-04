## Main UI controller - handles logic for scene-based layout
## Uses reactive signal-based architecture for real-time updates
## Supports drag-drop panel rearrangement
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

## Category lock toggles
@onready var lock_molecules_btn: CheckButton = %LockMoleculesBtn
@onready var lock_enzymes_btn: CheckButton = %LockEnzymesBtn
@onready var lock_genes_btn: CheckButton = %LockGenesBtn
@onready var lock_reactions_btn: CheckButton = %LockReactionsBtn
@onready var lock_mutations_btn: CheckButton = %LockMutationsBtn
@onready var isolate_option: OptionButton = %IsolateOption
@onready var mutation_rate_slider: HSlider = %MutationRateSlider
@onready var mutation_rate_label: Label = %MutationRateLabel

## Main layout
@onready var main_area: HSplitContainer = %MainArea
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

## Content panels - these are children added to the dock panels
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
var is_paused: bool = true  ## Start paused

var panel_visibility: Dictionary = {
	"cell": true,
	"reactions": true,
	"enzymes": true,
	"molecules": true,
	"genes": true,
	"chart": true
}

var all_docks: Array[DockPanel] = []
var all_columns: Array[VSplitContainer] = []

## Drag and drop state
var dragging_panel: DockPanel = null
var drop_indicator: Panel = null

#endregion

#region Initialization

func _ready() -> void:
	_setup_view_menu()
	_setup_isolate_menu()
	_cache_docks()
	_setup_drop_indicator()
	
	await get_tree().process_frame
	
	_connect_signals()
	_connect_drag_drop_signals()
	_show_empty_state()
	_sync_lock_buttons()
	_update_pause_button()

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

func _setup_isolate_menu() -> void:
	if not isolate_option:
		return
	isolate_option.clear()
	isolate_option.add_item("Run All", 0)
	isolate_option.add_separator()
	isolate_option.add_item("Test Molecules", 1)
	isolate_option.add_item("Test Enzymes", 2)
	isolate_option.add_item("Test Genes", 3)
	isolate_option.add_item("Test Reactions", 4)
	isolate_option.add_item("Test Mutations", 5)
	isolate_option.add_separator()
	isolate_option.add_item("Lock All", 6)

func _cache_docks() -> void:
	all_docks = [cell_dock, reactions_dock, enzymes_dock, molecules_dock, genes_dock, chart_dock]
	all_columns = [left_column, middle_column, right_column]

func _setup_drop_indicator() -> void:
	drop_indicator = Panel.new()
	drop_indicator.custom_minimum_size = Vector2(0, 6)
	drop_indicator.visible = false
	drop_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.7, 1.0, 0.9)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	drop_indicator.add_theme_stylebox_override("panel", style)
	
	add_child(drop_indicator)

func _connect_signals() -> void:
	if not sim_engine:
		push_error("SimEngine not found!")
		return
	
	## Main simulation update (for chart and bulk updates)
	sim_engine.simulation_updated.connect(_on_simulation_updated)
	sim_engine.simulation_started.connect(_on_simulation_started)
	sim_engine.simulation_stopped.connect(_on_simulation_stopped)
	
	## Category lock signals (reactive UI updates)
	sim_engine.molecules_lock_changed.connect(_on_molecules_lock_changed)
	sim_engine.enzymes_lock_changed.connect(_on_enzymes_lock_changed)
	sim_engine.genes_lock_changed.connect(_on_genes_lock_changed)
	sim_engine.reactions_lock_changed.connect(_on_reactions_lock_changed)
	sim_engine.mutations_lock_changed.connect(_on_mutations_lock_changed)
	
	## Mutation signals
	sim_engine.mutation_applied.connect(_on_mutation_applied)
	
	## Entity signals
	sim_engine.molecule_added.connect(_on_molecule_added)
	sim_engine.enzyme_added.connect(_on_enzyme_added)
	sim_engine.gene_added.connect(_on_gene_added)
	
	## Window resize
	get_tree().root.size_changed.connect(_on_window_resized)
	
	## Connect concentration panel signals
	if enzyme_panel:
		enzyme_panel.concentration_changed.connect(_on_enzyme_concentration_changed)
		enzyme_panel.lock_changed.connect(_on_enzyme_lock_changed)
	
	if molecule_panel:
		molecule_panel.concentration_changed.connect(_on_molecule_concentration_changed)
		molecule_panel.lock_changed.connect(_on_molecule_lock_changed)
	
	## Connect gene panel signals
	if gene_panel:
		gene_panel.gene_toggled.connect(_on_gene_toggled)

func _connect_drag_drop_signals() -> void:
	## Connect drag/drop signals for each dock panel
	for dock in all_docks:
		dock.drag_started.connect(_on_dock_drag_started)
		dock.drag_ended.connect(_on_dock_drag_ended)
		dock.drop_requested.connect(_on_dock_drop_requested)

## Show empty state before simulation starts
func _show_empty_state() -> void:
	if cell_content:
		cell_content.text = "[color=gray]Click ▶ Start to begin simulation[/color]"
	if reactions_content:
		reactions_content.text = "[color=gray]No reactions yet[/color]"
	if enzyme_panel:
		enzyme_panel.clear()
	if molecule_panel:
		molecule_panel.clear()
	if gene_panel:
		gene_panel.clear()
	if chart_panel:
		chart_panel.clear()

## Setup panels with data from simulator
func _setup_panels() -> void:
	if not sim_engine or not sim_engine.has_data():
		return
	
	if enzyme_panel:
		enzyme_panel.setup_items(sim_engine.enzymes.values(), "enzyme")
	if molecule_panel:
		molecule_panel.setup_items(sim_engine.molecules.values(), "molecule")
	if gene_panel:
		gene_panel.setup_genes(sim_engine.genes, sim_engine.enzymes)

func _sync_lock_buttons() -> void:
	## Sync button states with simulator state
	if not sim_engine:
		return
	
	if lock_molecules_btn:
		lock_molecules_btn.set_pressed_no_signal(sim_engine.lock_molecules)
	if lock_enzymes_btn:
		lock_enzymes_btn.set_pressed_no_signal(sim_engine.lock_enzymes)
	if lock_genes_btn:
		lock_genes_btn.set_pressed_no_signal(sim_engine.lock_genes)
	if lock_reactions_btn:
		lock_reactions_btn.set_pressed_no_signal(sim_engine.lock_reactions)
	if lock_mutations_btn:
		lock_mutations_btn.set_pressed_no_signal(sim_engine.lock_mutations)
	
	## Sync mutation rate slider
	if mutation_rate_slider and sim_engine.mutation_system:
		mutation_rate_slider.set_value_no_signal(sim_engine.mutation_system.enzyme_mutation_rate)
		if mutation_rate_label:
			mutation_rate_label.text = "%.3f/s" % sim_engine.mutation_system.enzyme_mutation_rate
	
	_update_lock_button_styles()

func _update_pause_button() -> void:
	if not pause_button or not sim_engine:
		return
	
	if not sim_engine.is_initialized:
		pause_button.text = "▶ Start"
	elif sim_engine.paused:
		pause_button.text = "▶ Resume"
	else:
		pause_button.text = "⏸ Pause"

#endregion

#region Drag and Drop Handling

func _on_dock_drag_started(panel: DockPanel) -> void:
	dragging_panel = panel
	panel.modulate = Color(1.0, 1.0, 1.0, 0.6)

func _on_dock_drag_ended(panel: DockPanel) -> void:
	dragging_panel = null
	panel.modulate = Color.WHITE
	drop_indicator.visible = false

func _on_dock_drop_requested(source_panel: DockPanel, target_container: Control, target_index: int) -> void:
	_move_panel_to(source_panel, target_container, target_index)

func _move_panel_to(panel: DockPanel, target_container: Control, target_index: int) -> void:
	var old_parent = panel.get_parent()
	
	## Remove from old parent
	if old_parent:
		old_parent.remove_child(panel)
	
	## Add to new container at specified index
	target_container.add_child(panel)
	if target_index >= 0 and target_index < target_container.get_child_count():
		target_container.move_child(panel, target_index)

func _process(_delta: float) -> void:
	## Handle drag preview indicator
	if dragging_panel and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_drop_indicator()
	elif drop_indicator.visible:
		drop_indicator.visible = false

func _update_drop_indicator() -> void:
	var mouse_pos = get_global_mouse_position()
	
	## Find which column we're over
	for column in all_columns:
		var col_rect = column.get_global_rect()
		if col_rect.has_point(mouse_pos):
			## We're over this column - find drop position
			var local_pos = column.get_local_mouse_position()
			var target_index = _get_drop_index_in_column(column, local_pos.y)
			
			## Position the indicator
			_show_drop_indicator_at(column, target_index)
			return
	
	drop_indicator.visible = false

func _get_drop_index_in_column(column: VSplitContainer, local_y: float) -> int:
	var children = column.get_children()
	
	for i in range(children.size()):
		var child = children[i]
		if not child is Control or child == drop_indicator:
			continue
		
		var child_rect = child.get_rect()
		var child_center_y = child_rect.position.y + child_rect.size.y / 2
		
		if local_y < child_center_y:
			return i
	
	return children.size()

func _show_drop_indicator_at(column: VSplitContainer, index: int) -> void:
	var children = column.get_children()
	
	if children.is_empty():
		## Empty column - show at top
		var col_rect = column.get_global_rect()
		drop_indicator.global_position = col_rect.position
		drop_indicator.size = Vector2(col_rect.size.x, 6)
	elif index >= children.size():
		## After last child
		var last_child = children[children.size() - 1] as Control
		var last_rect = last_child.get_global_rect()
		drop_indicator.global_position = Vector2(last_rect.position.x, last_rect.end.y + 2)
		drop_indicator.size = Vector2(last_rect.size.x, 6)
	else:
		## Before specific child
		var target_child = children[index] as Control
		var target_rect = target_child.get_global_rect()
		drop_indicator.global_position = Vector2(target_rect.position.x, target_rect.position.y - 4)
		drop_indicator.size = Vector2(target_rect.size.x, 6)
	
	drop_indicator.visible = true

func _input(event: InputEvent) -> void:
	## Handle drop on mouse release
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and dragging_panel:
			_perform_drop()
			dragging_panel = null
			drop_indicator.visible = false

func _perform_drop() -> void:
	if not dragging_panel:
		return
	
	var mouse_pos = get_global_mouse_position()
	
	## Find which column we're over
	for column in all_columns:
		var col_rect = column.get_global_rect()
		if col_rect.has_point(mouse_pos):
			var local_pos = column.get_local_mouse_position()
			var target_index = _get_drop_index_in_column(column, local_pos.y)
			
			## Don't move if same position
			var current_parent = dragging_panel.get_parent()
			var current_index = current_parent.get_children().find(dragging_panel) if current_parent else -1
			
			if current_parent != column or current_index != target_index:
				_move_panel_to(dragging_panel, column, target_index)
			
			return

#endregion

#region Simulation Lifecycle Handlers

func _on_simulation_started() -> void:
	is_paused = false
	_setup_panels()
	_update_pause_button()

func _on_simulation_stopped() -> void:
	is_paused = true
	_update_pause_button()

#endregion

#region Lock Signal Handlers (Reactive UI)

func _on_molecules_lock_changed(locked: bool) -> void:
	if lock_molecules_btn:
		lock_molecules_btn.set_pressed_no_signal(locked)
	_update_lock_button_styles()
	_update_isolate_option_display()

func _on_enzymes_lock_changed(locked: bool) -> void:
	if lock_enzymes_btn:
		lock_enzymes_btn.set_pressed_no_signal(locked)
	_update_lock_button_styles()
	_update_isolate_option_display()

func _on_genes_lock_changed(locked: bool) -> void:
	if lock_genes_btn:
		lock_genes_btn.set_pressed_no_signal(locked)
	_update_lock_button_styles()
	_update_isolate_option_display()

func _on_reactions_lock_changed(locked: bool) -> void:
	if lock_reactions_btn:
		lock_reactions_btn.set_pressed_no_signal(locked)
	_update_lock_button_styles()
	_update_isolate_option_display()

func _on_mutations_lock_changed(locked: bool) -> void:
	if lock_mutations_btn:
		lock_mutations_btn.set_pressed_no_signal(locked)
	_update_lock_button_styles()
	_update_isolate_option_display()

func _on_mutation_applied(mutation_type: String, details: Dictionary) -> void:
	## Could add visual feedback here - flash, sound, log, etc.
	## For now just log significant mutations
	if mutation_type == "duplication" or mutation_type == "novel":
		print("🧬 Mutation: %s - %s" % [mutation_type, details.get("enzyme_name", "unknown")])

func _update_lock_button_styles() -> void:
	## Visual feedback for locked state
	var locked_color = Color(1.0, 0.4, 0.3)
	var unlocked_color = Color(0.3, 0.9, 0.4)
	
	if lock_molecules_btn:
		var color = locked_color if lock_molecules_btn.button_pressed else unlocked_color
		lock_molecules_btn.add_theme_color_override("font_color", color)
	
	if lock_enzymes_btn:
		var color = locked_color if lock_enzymes_btn.button_pressed else unlocked_color
		lock_enzymes_btn.add_theme_color_override("font_color", color)
	
	if lock_genes_btn:
		var color = locked_color if lock_genes_btn.button_pressed else unlocked_color
		lock_genes_btn.add_theme_color_override("font_color", color)
	
	if lock_reactions_btn:
		var color = locked_color if lock_reactions_btn.button_pressed else unlocked_color
		lock_reactions_btn.add_theme_color_override("font_color", color)
	
	if lock_mutations_btn:
		var color = locked_color if lock_mutations_btn.button_pressed else unlocked_color
		lock_mutations_btn.add_theme_color_override("font_color", color)

func _update_isolate_option_display() -> void:
	## Update isolate dropdown to reflect current state
	if not isolate_option or not sim_engine:
		return
	
	var all_locked = sim_engine.lock_molecules and sim_engine.lock_enzymes and sim_engine.lock_genes and sim_engine.lock_reactions and sim_engine.lock_mutations
	var none_locked = not sim_engine.lock_molecules and not sim_engine.lock_enzymes and not sim_engine.lock_genes and not sim_engine.lock_reactions and not sim_engine.lock_mutations
	
	if none_locked:
		isolate_option.select(0)  ## Run All
	elif all_locked:
		isolate_option.select(6)  ## Lock All
	elif not sim_engine.lock_molecules and sim_engine.lock_enzymes and sim_engine.lock_genes and sim_engine.lock_reactions and sim_engine.lock_mutations:
		isolate_option.select(1)  ## Test Molecules
	elif sim_engine.lock_molecules and not sim_engine.lock_enzymes and sim_engine.lock_genes and sim_engine.lock_reactions and sim_engine.lock_mutations:
		isolate_option.select(2)  ## Test Enzymes
	elif sim_engine.lock_molecules and sim_engine.lock_enzymes and not sim_engine.lock_genes and sim_engine.lock_reactions and sim_engine.lock_mutations:
		isolate_option.select(3)  ## Test Genes
	elif sim_engine.lock_molecules and sim_engine.lock_enzymes and sim_engine.lock_genes and not sim_engine.lock_reactions and sim_engine.lock_mutations:
		isolate_option.select(4)  ## Test Reactions
	elif sim_engine.lock_molecules and sim_engine.lock_enzymes and sim_engine.lock_genes and sim_engine.lock_reactions and not sim_engine.lock_mutations:
		isolate_option.select(5)  ## Test Mutations

#endregion

#region Entity Signal Handlers

func _on_molecule_added(molecule: Molecule) -> void:
	## Reactively add new molecule to UI
	if molecule_panel:
		molecule_panel.add_item(molecule, "molecule")

func _on_enzyme_added(enzyme: Enzyme) -> void:
	## Reactively add new enzyme to UI
	if enzyme_panel:
		enzyme_panel.add_item(enzyme, "enzyme")

func _on_gene_added(gene: Gene) -> void:
	## Reactively add new gene to UI
	if gene_panel and sim_engine:
		var enzyme = sim_engine.enzymes.get(gene.enzyme_id)
		gene_panel.add_gene(gene, enzyme)

#endregion

#region Layout Management

func _apply_layout(mode: LayoutMode) -> void:
	current_layout = mode
	
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
	var mutation_stats = data.get("mutation_stats", {})
	var recent_mutations: Array = data.get("recent_mutations", [])
	var locks = data.get("locks", {})
	
	var text = ""
	var status_color = "green" if cell.is_alive else "red"
	var status_text = "ALIVE" if cell.is_alive else "DEAD"
	text += "[b]Status:[/b] [color=%s]%s[/color]\n" % [status_color, status_text]
	text += "[b]Time:[/b] %.1f s\n\n" % data.get("time", 0.0)
	
	## Show lock status
	var active_locks: Array[String] = []
	if locks.get("molecules", false):
		active_locks.append("Mol")
	if locks.get("enzymes", false):
		active_locks.append("Enz")
	if locks.get("genes", false):
		active_locks.append("Gen")
	if locks.get("reactions", false):
		active_locks.append("Rxn")
	if locks.get("mutations", false):
		active_locks.append("Mut")
	
	if not active_locks.is_empty():
		text += "[color=orange]🔒 Locked: %s[/color]\n\n" % ", ".join(active_locks)
	
	text += "[color=yellow]━━ Thermal ━━[/color]\n"
	text += "Heat: %.1f / %.1f\n" % [thermal.heat, thermal.max_threshold]
	text += "Generated: %.2f kJ\n\n" % energy.total_heat
	
	text += "[color=cyan]━━ Energy ━━[/color]\n"
	text += "Usable: %.2f kJ\n" % energy.usable_energy
	text += "Net: %.2f kJ\n\n" % energy.net_energy
	
	text += "[color=lime]━━ Proteins ━━[/color]\n"
	text += "Synth: %.4f mM\n" % protein.get("total_synthesized", 0.0)
	text += "Degrad: %.4f mM\n" % protein.get("total_degraded", 0.0)
	text += "↑%d ↓%d genes\n\n" % [protein.get("upregulated_genes", 0), protein.get("downregulated_genes", 0)]
	
	## Mutations section
	text += "[color=magenta]━━ Mutations ━━[/color]\n"
	text += "Total: %d\n" % mutation_stats.get("total_mutations", 0)
	if not recent_mutations.is_empty():
		text += "Recent:\n"
		for event in recent_mutations:
			if event is Dictionary:
				text += "  %s\n" % event.get("summary", "unknown")
	
	cell_content.text = text

func _update_reactions_panel(data: Dictionary) -> void:
	if not reactions_content or not reactions_dock.visible:
		return
	
	var reactions_arr: Array = data.get("reactions", [])
	var locks = data.get("locks", {})
	var is_locked = locks.get("reactions", false)
	
	var text = ""
	
	if is_locked:
		text += "[color=orange]🔒 Reactions Locked[/color]\n\n"
	
	if reactions_arr.is_empty():
		text += "[color=gray]No reactions[/color]"
	else:
		for rxn in reactions_arr:
			var net_rate = rxn.get_net_rate()
			var rate_color = "gray" if is_locked else ("lime" if net_rate > 0.001 else ("orange" if net_rate < -0.001 else "gray"))
			
			text += "[b]%s[/b]\n" % rxn.get_summary()
			text += "  η=%.0f%% ΔG=%.1f kJ/mol\n" % [rxn.reaction_efficiency * 100.0, rxn.current_delta_g_actual]
			text += "  [color=%s]Net: %.4f mM/s[/color]\n\n" % [rate_color, net_rate]
	
	reactions_content.text = text

func _update_enzymes_panel(data: Dictionary) -> void:
	if not enzyme_panel or not enzymes_dock.visible:
		return
	var enzymes_dict: Dictionary = data.get("enzymes", {})
	var locks = data.get("locks", {})
	enzyme_panel.update_values(enzymes_dict.values(), "enzyme")
	enzyme_panel.set_category_locked(locks.get("enzymes", false))

func _update_molecules_panel(data: Dictionary) -> void:
	if not molecule_panel or not molecules_dock.visible:
		return
	var molecules_dict: Dictionary = data.get("molecules", {})
	var locks = data.get("locks", {})
	molecule_panel.update_values(molecules_dict.values(), "molecule")
	molecule_panel.set_category_locked(locks.get("molecules", false))

func _update_genes_panel(data: Dictionary) -> void:
	if not gene_panel or not genes_dock.visible:
		return
	var genes_dict: Dictionary = data.get("genes", {})
	var molecules_dict: Dictionary = data.get("molecules", {})
	var enzymes_dict: Dictionary = data.get("enzymes", {})
	var locks = data.get("locks", {})
	gene_panel.update_genes(genes_dict, molecules_dict, enzymes_dict)
	gene_panel.set_category_locked(locks.get("genes", false))

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
	
	chart_panel.update_chart(chart_data, auto_scale_check.button_pressed)

#endregion

#region UI Callbacks

func _on_pause_pressed() -> void:
	if not sim_engine:
		return
	
	if not sim_engine.is_initialized:
		## First time - start the simulation
		sim_engine.start_simulation()
	elif sim_engine.paused:
		## Resume
		sim_engine.set_paused(false)
		sim_engine.is_running = true
	else:
		## Pause
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

func _toggle_panel(panel_name_key: String, popup: PopupMenu, index: int) -> void:
	panel_visibility[panel_name_key] = not panel_visibility[panel_name_key]
	popup.set_item_checked(index, panel_visibility[panel_name_key])
	_apply_panel_visibility()

func _on_panel_visibility_changed(pname: String, p_is_visible: bool) -> void:
	panel_visibility[pname] = p_is_visible
	var popup = view_menu.get_popup()
	var indices = {"cell": 0, "reactions": 1, "enzymes": 2, "molecules": 3, "genes": 4, "chart": 5}
	if indices.has(pname):
		popup.set_item_checked(indices[pname], p_is_visible)

func _on_chart_mode_changed(index: int) -> void:
	chart_mode = index as ChartMode

func _on_auto_scale_toggled(_pressed: bool) -> void:
	pass

#endregion

#region Category Lock Callbacks

func _on_lock_molecules_toggled(pressed: bool) -> void:
	if sim_engine:
		sim_engine.lock_molecules = pressed

func _on_lock_enzymes_toggled(pressed: bool) -> void:
	if sim_engine:
		sim_engine.lock_enzymes = pressed

func _on_lock_genes_toggled(pressed: bool) -> void:
	if sim_engine:
		sim_engine.lock_genes = pressed

func _on_lock_reactions_toggled(pressed: bool) -> void:
	if sim_engine:
		sim_engine.lock_reactions = pressed

func _on_lock_mutations_toggled(pressed: bool) -> void:
	if sim_engine:
		sim_engine.lock_mutations = pressed

func _on_mutation_rate_changed(value: float) -> void:
	if sim_engine and sim_engine.mutation_system:
		sim_engine.mutation_system.enzyme_mutation_rate = value
		if mutation_rate_label:
			mutation_rate_label.text = "%.3f/s" % value

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

#endregion

#region Item-Level Callbacks

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
