## UI Manager for Enzyme Simulator
## Handles all UI building, updating, and event handling
## Separated from simulation logic

class_name SimulatorUI
extends Control

var simulator: EnzymeSimulator

## UI element storage
var molecule_ui_elements: Dictionary = {}
var enzyme_list_buttons: Dictionary = {}

## UI References
var stats_label: Label
var pause_button: Button
var molecules_panel: VBoxContainer
var enzyme_list_container: VBoxContainer
var enzyme_detail_container: VBoxContainer
var molecule_detail_container: VBoxContainer

func _init(sim: EnzymeSimulator) -> void:
	simulator = sim
	set_anchors_preset(Control.PRESET_FULL_RECT)

func build_ui() -> void:
	## Create background
	var background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.118, 0.235, 0.447)
	add_child(background)
	
	## Create main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	
	## Main horizontal layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)
	
	## Build left and right panels
	build_left_panel(hbox)
	build_right_panel(hbox)

func build_left_panel(parent: HBoxContainer) -> void:
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.7
	left_panel.add_theme_constant_override("separation", 20)
	parent.add_child(left_panel)
	
	## Title
	var title = Label.new()
	title.text = "🧬 Enzyme Simulator"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Thermodynamic Regulation"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(subtitle)
	
	## Stats and thermodynamic summary
	var stats_thermo_hbox = HBoxContainer.new()
	stats_thermo_hbox.add_theme_constant_override("separation", 20)
	left_panel.add_child(stats_thermo_hbox)
	
	stats_label = Label.new()
	stats_label.text = "Time: 0.0s | Iteration: 0"
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_thermo_hbox.add_child(stats_label)
	
	var thermo_summary = Label.new()
	thermo_summary.name = "ThermoSummary"
	thermo_summary.text = "⚡ System Energetics"
	thermo_summary.add_theme_font_size_override("font_size", 14)
	thermo_summary.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	stats_thermo_hbox.add_child(thermo_summary)
	
	## Control buttons
	var control_hbox = HBoxContainer.new()
	control_hbox.add_theme_constant_override("separation", 15)
	control_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_panel.add_child(control_hbox)
	
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.custom_minimum_size = Vector2(120, 40)
	pause_button.pressed.connect(simulator._on_pause_button_pressed)
	pause_button.pressed.connect(func(): pause_button.text = "Resume" if simulator.is_paused else "Pause")
	control_hbox.add_child(pause_button)
	
	var reset_button = Button.new()
	reset_button.text = "Reset"
	reset_button.custom_minimum_size = Vector2(120, 40)
	reset_button.pressed.connect(simulator._on_reset_button_pressed)
	control_hbox.add_child(reset_button)
	
	## Molecules panel
	build_molecules_panel(left_panel)
	
	## Molecule detail panel
	build_molecule_detail_panel(left_panel)

func build_molecules_panel(parent: VBoxContainer) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "📊 Molecules"
	title.add_theme_color_override("font_color", Color(0.3, 0.686, 0.314))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var add_btn = Button.new()
	add_btn.text = "+ Add Molecule"
	add_btn.pressed.connect(simulator._on_add_molecule_pressed)
	vbox.add_child(add_btn)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	molecules_panel = VBoxContainer.new()
	molecules_panel.add_theme_constant_override("separation", 5)
	molecules_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(molecules_panel)

func build_molecule_detail_panel(parent: VBoxContainer) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Molecule Details"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	molecule_detail_container = VBoxContainer.new()
	molecule_detail_container.add_theme_constant_override("separation", 10)
	molecule_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(molecule_detail_container)
	
	var placeholder = Label.new()
	placeholder.text = "Click a molecule info button to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(placeholder)

func build_right_panel(parent: HBoxContainer) -> void:
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.5
	right_panel.add_theme_constant_override("separation", 20)
	parent.add_child(right_panel)
	
	## Header with add button
	var header = HBoxContainer.new()
	right_panel.add_child(header)
	
	var title = Label.new()
	title.text = "⚗️ Enzymes"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.3, 0.686, 0.314))
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	
	var add_btn = Button.new()
	add_btn.text = "+ Add Enzyme"
	add_btn.custom_minimum_size = Vector2(150, 40)
	add_btn.pressed.connect(simulator._on_add_enzyme_pressed)
	header.add_child(add_btn)
	
	## Split container for list and details
	var hsplit = HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(hsplit)
	
	build_enzyme_list_panel(hsplit)
	build_enzyme_detail_panel(hsplit)

func build_enzyme_list_panel(parent: HSplitContainer) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	parent.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Enzyme List"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	enzyme_list_container = VBoxContainer.new()
	enzyme_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enzyme_list_container.add_theme_constant_override("separation", 5)
	scroll.add_child(enzyme_list_container)

func build_enzyme_detail_panel(parent: HSplitContainer) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	
	var scroll = ScrollContainer.new()
	panel.add_child(scroll)
	
	enzyme_detail_container = VBoxContainer.new()
	enzyme_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enzyme_detail_container.add_theme_constant_override("separation", 15)
	scroll.add_child(enzyme_detail_container)
	
	var placeholder = Label.new()
	placeholder.text = "Select an enzyme to view details"
	placeholder.add_theme_font_size_override("font_size", 16)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(placeholder)

## ============================================================================
## UPDATE FUNCTIONS
## ============================================================================

func update_all() -> void:
	update_stats()
	update_molecule_list()
	update_enzyme_list()
	
	if simulator.selected_enzyme:
		update_enzyme_detail()
	if simulator.selected_molecule != "":
		update_molecule_detail()

func update_stats() -> void:
	stats_label.text = "Time: %.1fs | Iteration: %d" % [simulator.total_time, simulator.iteration]
	
	## Calculate system thermodynamics
	var total_dg = 0.0
	var favorable_count = 0
	var unfavorable_count = 0
	var equilibrium_count = 0
	
	for enzyme in simulator.enzymes:
		total_dg += enzyme.current_delta_g
		if enzyme.current_delta_g < -5.0:
			favorable_count += 1
		elif enzyme.current_delta_g > 5.0:
			unfavorable_count += 1
		else:
			equilibrium_count += 1
	
	## Update thermodynamic summary
	for child in get_children():
		_find_and_update_thermo_summary(child, favorable_count, unfavorable_count, equilibrium_count)

func _find_and_update_thermo_summary(node: Node, fav: int, unfav: int, eq: int) -> void:
	if node.name == "ThermoSummary":
		var status = ""
		if fav > unfav + eq:
			status = "→ Active"
		elif eq > fav + unfav:
			status = "⇄ Equilibrating"
		else:
			status = "← Mixed"
		node.text = "⚡ %s (Fwd:%d Eq:%d Rev:%d)" % [status, fav, eq, unfav]
	for child in node.get_children():
		_find_and_update_thermo_summary(child, fav, unfav, eq)

func update_molecule_list() -> void:
	for mol_name in simulator.molecules.keys():
		if molecule_ui_elements.has(mol_name):
			var mol = simulator.molecules[mol_name]
			var ui = molecule_ui_elements[mol_name]
			ui["label"].text = "  %s: %.3f mM" % [mol.name, mol.concentration]

func update_enzyme_list() -> void:
	for enzyme in simulator.enzymes:
		if enzyme_list_buttons.has(enzyme.id):
			var btn = enzyme_list_buttons[enzyme.id]
			var type_str = ""
			if enzyme.is_source():
				type_str = " [SOURCE]"
			elif enzyme.is_sink():
				type_str = " [SINK]"

			var net_rate = enzyme.current_forward_rate - enzyme.current_reverse_rate
			
			## Add ΔG indicator
			var dg_indicator = ""
			if abs(enzyme.current_delta_g) < 0.1:
				dg_indicator = " ⇄"  # At equilibrium
			elif enzyme.current_delta_g < -10:
				dg_indicator = " →→"  # Strongly forward
			elif enzyme.current_delta_g < 0:
				dg_indicator = " →"   # Forward
			elif enzyme.current_delta_g > 10:
				dg_indicator = " ←←"  # Strongly reverse
			else:
				dg_indicator = " ←"   # Reverse
			
			btn.text = "%s%s%s\nNet: %.3f mM/s\nΔG: %.1f kJ/mol\n[E]: %.4f" % [
				enzyme.name, 
				type_str, 
				dg_indicator,
				net_rate, 
				enzyme.current_delta_g,
				enzyme.concentration
			]

func update_enzyme_detail() -> void:
	if not simulator.selected_enzyme:
		return
	
	var enzyme = simulator.selected_enzyme
	
	for child in enzyme_detail_container.get_children():
		if child.name == "RateInfo":
			var net_rate = enzyme.current_forward_rate - enzyme.current_reverse_rate
			child.text = "Forward: %.3f mM/s\nReverse: %.3f mM/s\nNet: %.3f mM/s" % [
				enzyme.current_forward_rate,
				enzyme.current_reverse_rate,
				net_rate
			]
		elif child.name == "ConcentrationLabel":
			child.text = "Enzyme Concentration: %.4f mM" % enzyme.concentration
	
	## Update thermodynamics panel
	for child in enzyme_detail_container.get_children():
		if child is PanelContainer:
			var vbox = child.get_child(0) if child.get_child_count() > 0 else null
			if vbox:
				for label in vbox.get_children():
					if label.name == "ThermodynamicsInfo":
						label.text = "ΔG: %.1f kJ/mol" % enzyme.current_delta_g
						var dg_color = Color.GREEN if enzyme.current_delta_g < 0 else Color.RED
						label.add_theme_color_override("font_color", dg_color)
					elif label.name == "DirectionInfo":
						var direction_text = ""
						var direction_color = Color.WHITE
						if enzyme.current_delta_g < -5.0:
							direction_text = "→ Forward Favorable"
							direction_color = Color(0.4, 1.0, 0.4)
						elif enzyme.current_delta_g > 5.0:
							direction_text = "← Reverse Favorable"
							direction_color = Color(1.0, 0.5, 0.3)
						else:
							direction_text = "⇄ Near Equilibrium"
							direction_color = Color(1.0, 1.0, 0.4)
						label.text = direction_text
						label.add_theme_color_override("font_color", direction_color)
					elif label.name == "DeltaGStandard":
						label.text = "ΔG°: %.1f kJ/mol" % enzyme.delta_g_standard
					elif label.name == "KeqInfo":
						var keq = enzyme.calculate_keq()
						var keq_text = ""
						if keq > 1000:
							keq_text = "Keq: %.1e (strongly forward)" % keq
						elif keq > 10:
							keq_text = "Keq: %.1f (favors forward)" % keq
						elif keq > 0.1:
							keq_text = "Keq: %.2f (near equilibrium)" % keq
						else:
							keq_text = "Keq: %.1e (favors reverse)" % keq
						label.text = keq_text

func update_molecule_detail() -> void:
	if simulator.selected_molecule == "" or not simulator.molecules.has(simulator.selected_molecule):
		return
	
	var mol = simulator.molecules[simulator.selected_molecule]
	
	## Update concentration
	for child in molecule_detail_container.get_children():
		if child.name == "ConcentrationLabel":
			child.text = "Concentration: %.3f mM" % mol.concentration
	
	## Update enzyme rates
	for enzyme in simulator.enzymes:
		var rate_label_name = "RateLabel_%s" % enzyme.id
		var net_rate = enzyme.current_forward_rate - enzyme.current_reverse_rate
		
		for child in molecule_detail_container.get_children():
			if child is Panel:
				var vbox = child.get_child(0) if child.get_child_count() > 0 else null
				if vbox:
					for label in vbox.get_children():
						if label.name == rate_label_name:
							if enzyme.products.has(simulator.selected_molecule):
								var stoich = enzyme.products[simulator.selected_molecule]
								var rate = net_rate * stoich
								label.text = "+%.3f mM/s (stoich: ×%.1f)" % [rate, stoich]
							elif enzyme.substrates.has(simulator.selected_molecule):
								var stoich = enzyme.substrates[simulator.selected_molecule]
								var rate = net_rate * stoich
								label.text = "-%.3f mM/s (stoich: ×%.1f)" % [rate, stoich]
	
	## Update net rate
	var net_rate = 0.0
	for enzyme in simulator.enzymes:
		var enzyme_net = enzyme.current_forward_rate - enzyme.current_reverse_rate
		if enzyme.products.has(simulator.selected_molecule):
			var stoich = enzyme.products[simulator.selected_molecule]
			net_rate += enzyme_net * stoich
		if enzyme.substrates.has(simulator.selected_molecule):
			var stoich = enzyme.substrates[simulator.selected_molecule]
			net_rate -= enzyme_net * stoich
	
	for child in molecule_detail_container.get_children():
		if child.name == "NetRateLabel":
			var net_sign = "+" if net_rate >= 0 else ""
			var net_color = Color(0.4, 1.0, 0.4) if net_rate >= 0 else Color(1.0, 0.4, 0.4)
			child.text = "%s%.3f mM/s" % [net_sign, net_rate]
			child.add_theme_color_override("font_color", net_color)

## ============================================================================
## BUILD/REBUILD FUNCTIONS
## ============================================================================

func rebuild_molecule_list() -> void:
	## Clear existing
	for child in molecules_panel.get_children():
		child.queue_free()
	molecule_ui_elements.clear()
	
	## Rebuild all
	for mol_name in simulator.molecules.keys():
		add_molecule_ui(mol_name)

func add_molecule_ui(mol_name: String) -> void:
	var mol = simulator.molecules[mol_name]
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	molecules_panel.add_child(hbox)

	## Draggable molecule button
	var drag_btn = Button.new()
	drag_btn.text = "⋮⋮"
	drag_btn.custom_minimum_size = Vector2(30, 0)
	drag_btn.tooltip_text = "Drag to enzyme slots"
	drag_btn.button_down.connect(func(): simulator.start_molecule_drag(mol_name))
	drag_btn.button_up.connect(func(): simulator.stop_molecule_drag())
	hbox.add_child(drag_btn)

	var label = Label.new()
	label.text = "  %s: %.3f mM" % [mol_name, mol.concentration]
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	## Info button
	var info_btn = Button.new()
	info_btn.text = "ℹ"
	info_btn.custom_minimum_size = Vector2(30, 0)
	info_btn.tooltip_text = "View molecule details"
	info_btn.pressed.connect(func(): simulator.on_molecule_info_clicked(mol_name))
	hbox.add_child(info_btn)

	## Delete button
	var delete_btn = Button.new()
	delete_btn.text = "✕"
	delete_btn.custom_minimum_size = Vector2(30, 0)
	delete_btn.pressed.connect(func(): 
		if simulator.remove_molecule(mol_name):
			rebuild_molecule_list()
	)
	hbox.add_child(delete_btn)

	molecule_ui_elements[mol_name] = {
		"label": label,
		"container": hbox
	}

func rebuild_enzyme_list() -> void:
	## Clear existing
	for child in enzyme_list_container.get_children():
		child.queue_free()
	enzyme_list_buttons.clear()
	
	## Rebuild all
	for enzyme in simulator.enzymes:
		add_enzyme_button(enzyme)

func add_enzyme_button(enzyme: Enzyme) -> void:
	var btn = Button.new()
	btn.text = "%s\n0.000 mM/s\n[E]: %.4f" % [enzyme.name, enzyme.concentration]
	btn.custom_minimum_size = Vector2(0, 80)
	btn.pressed.connect(simulator.on_enzyme_selected.bind(enzyme))
	enzyme_list_container.add_child(btn)
	enzyme_list_buttons[enzyme.id] = btn

## ============================================================================
## DETAIL VIEW BUILDERS
## ============================================================================

func show_enzyme_detail(enzyme: Enzyme) -> void:
	## Clear molecule detail
	for child in molecule_detail_container.get_children():
		child.queue_free()
	var placeholder = Label.new()
	placeholder.text = "Click a molecule info button to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(placeholder)
	
	## Build enzyme detail
	build_enzyme_detail_view(enzyme)

func show_molecule_detail(mol_name: String) -> void:
	## Clear enzyme detail
	for child in enzyme_detail_container.get_children():
		child.queue_free()
	var placeholder = Label.new()
	placeholder.text = "Select an enzyme to view details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(placeholder)
	
	## Build molecule detail
	build_molecule_detail_view(mol_name)

func build_enzyme_detail_view(enzyme: Enzyme) -> void:
	for child in enzyme_detail_container.get_children():
		child.queue_free()

	## Header
	var header_hbox = HBoxContainer.new()
	enzyme_detail_container.add_child(header_hbox)

	var title = Label.new()
	title.text = "⚗️ %s" % enzyme.name
	title.add_theme_color_override("font_color", Color(0.506, 0.784, 0.514))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	var delete_btn = Button.new()
	delete_btn.text = "Delete Enzyme"
	delete_btn.pressed.connect(func(): 
		simulator.remove_enzyme(enzyme)
		rebuild_enzyme_list()
		show_enzyme_detail(null)
	)
	header_hbox.add_child(delete_btn)

	## Rate info
	var net_rate = enzyme.current_forward_rate - enzyme.current_reverse_rate
	var rate_label = Label.new()
	rate_label.name = "RateInfo"
	rate_label.text = "Forward: %.3f mM/s\nReverse: %.3f mM/s\nNet: %.3f mM/s" % [
		enzyme.current_forward_rate,
		enzyme.current_reverse_rate,
		net_rate
	]
	rate_label.add_theme_color_override("font_color", Color(0.506, 0.784, 0.514))
	rate_label.add_theme_font_size_override("font_size", 14)
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(rate_label)

	## Thermodynamics info panel
	var thermo_panel = PanelContainer.new()
	enzyme_detail_container.add_child(thermo_panel)
	
	var thermo_vbox = VBoxContainer.new()
	thermo_vbox.add_theme_constant_override("separation", 5)
	thermo_panel.add_child(thermo_vbox)
	
	var thermo_title = Label.new()
	thermo_title.text = "⚡ Energetics"
	thermo_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	thermo_title.add_theme_font_size_override("font_size", 16)
	thermo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thermo_vbox.add_child(thermo_title)
	
	## ΔG (actual)
	var dg_label = Label.new()
	dg_label.name = "ThermodynamicsInfo"
	dg_label.text = "ΔG: %.1f kJ/mol" % enzyme.current_delta_g
	var dg_color = Color.GREEN if enzyme.current_delta_g < 0 else Color.RED
	dg_label.add_theme_color_override("font_color", dg_color)
	dg_label.add_theme_font_size_override("font_size", 16)
	dg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thermo_vbox.add_child(dg_label)
	
	## Direction indicator
	var direction_label = Label.new()
	direction_label.name = "DirectionInfo"
	var direction_text = ""
	var direction_color = Color.WHITE
	if enzyme.current_delta_g < -5.0:
		direction_text = "→ Forward Favorable"
		direction_color = Color(0.4, 1.0, 0.4)
	elif enzyme.current_delta_g > 5.0:
		direction_text = "← Reverse Favorable"
		direction_color = Color(1.0, 0.5, 0.3)
	else:
		direction_text = "⇄ Near Equilibrium"
		direction_color = Color(1.0, 1.0, 0.4)
	direction_label.text = direction_text
	direction_label.add_theme_color_override("font_color", direction_color)
	direction_label.add_theme_font_size_override("font_size", 14)
	direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thermo_vbox.add_child(direction_label)
	
	## ΔG° (standard)
	var dg_std_label = Label.new()
	dg_std_label.name = "DeltaGStandard"
	dg_std_label.text = "ΔG°: %.1f kJ/mol" % enzyme.delta_g_standard
	dg_std_label.add_theme_font_size_override("font_size", 12)
	dg_std_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thermo_vbox.add_child(dg_std_label)
	
	## Keq
	var keq_label = Label.new()
	keq_label.name = "KeqInfo"
	var keq = enzyme.calculate_keq()
	var keq_text = ""
	if keq > 1000:
		keq_text = "Keq: %.1e (strongly forward)" % keq
	elif keq > 10:
		keq_text = "Keq: %.1f (favors forward)" % keq
	elif keq > 0.1:
		keq_text = "Keq: %.2f (near equilibrium)" % keq
	else:
		keq_text = "Keq: %.1e (favors reverse)" % keq
	keq_label.text = keq_text
	keq_label.add_theme_font_size_override("font_size", 12)
	keq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thermo_vbox.add_child(keq_label)
	
	## Enzyme concentration
	var conc_label = Label.new()
	conc_label.name = "ConcentrationLabel"
	conc_label.text = "Enzyme Concentration: %.4f mM" % enzyme.concentration
	conc_label.add_theme_font_size_override("font_size", 14)
	conc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enzyme_detail_container.add_child(conc_label)

	## Substrates
	enzyme_detail_container.add_child(_create_section_label("Substrates"))
	for substrate in enzyme.substrates:
		var stoich = enzyme.substrates[substrate]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, substrate, "substrate", stoich))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "substrate"))

	## Products
	enzyme_detail_container.add_child(_create_section_label("Products"))
	for product in enzyme.products:
		var stoich = enzyme.products[product]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, product, "product", stoich))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "product"))

	## Competitive Inhibitors
	enzyme_detail_container.add_child(_create_section_label("Competitive Inhibitors (Ki)"))
	for inhibitor in enzyme.competitive_inhibitors:
		var ki = enzyme.competitive_inhibitors[inhibitor]
		enzyme_detail_container.add_child(create_molecule_slot(enzyme, inhibitor, "competitive_inhibitor", ki))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "competitive_inhibitor"))

	## Allosteric Inhibitors
	enzyme_detail_container.add_child(_create_section_label("Allosteric Inhibitors"))
	for inhibitor in enzyme.allosteric_inhibitors:
		var params = enzyme.allosteric_inhibitors[inhibitor]
		enzyme_detail_container.add_child(create_allosteric_slot(enzyme, inhibitor, "allosteric_inhibitor", params))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "allosteric_inhibitor"))

	## Allosteric Activators
	enzyme_detail_container.add_child(_create_section_label("Allosteric Activators"))
	for activator in enzyme.allosteric_activators:
		var params = enzyme.allosteric_activators[activator]
		enzyme_detail_container.add_child(create_allosteric_slot(enzyme, activator, "allosteric_activator", params))
	enzyme_detail_container.add_child(create_add_slot(enzyme, "allosteric_activator"))

	## Enzyme Dynamics
	enzyme_detail_container.add_child(_create_section_label("Enzyme Dynamics"))
	
	var creation_slider = create_parameter_slider("Base Creation Rate", enzyme.creation_rate, 0.0, 0.1, 0.001, 
		func(val): enzyme.creation_rate = val)
	enzyme_detail_container.add_child(creation_slider)
	
	var degr_slider = create_parameter_slider("Base Degradation Rate", enzyme.degradation_rate, 0.0, 0.5, 0.001,
		func(val): enzyme.degradation_rate = val)
	enzyme_detail_container.add_child(degr_slider)

	## Catalytic Parameters
	enzyme_detail_container.add_child(_create_section_label("Catalytic Parameters"))
	
	var kcat_f_slider = create_parameter_slider("kcat Forward (s⁻¹)", enzyme.kcat_forward, 0.0, 100.0, 0.1,
		func(val): enzyme.kcat_forward = val)
	enzyme_detail_container.add_child(kcat_f_slider)
	
	var kcat_r_slider = create_parameter_slider("kcat Reverse (s⁻¹)", enzyme.kcat_reverse, 0.0, 20.0, 0.1,
		func(val): enzyme.kcat_reverse = val)
	enzyme_detail_container.add_child(kcat_r_slider)

	## Thermodynamic Parameters
	enzyme_detail_container.add_child(_create_section_label("Thermodynamics"))
	
	var dg_slider = create_parameter_slider("ΔG° (kJ/mol)", enzyme.delta_g_standard, -50.0, 50.0, 0.5,
		func(val): enzyme.delta_g_standard = val)
	enzyme_detail_container.add_child(dg_slider)
	
	var conc_slider = create_parameter_slider("Initial [E] (mM)", enzyme.concentration, 0.0, 0.1, 0.001,
		func(val): 
			enzyme.concentration = val
			enzyme.initial_concentration = val
	)
	enzyme_detail_container.add_child(conc_slider)

func build_molecule_detail_view(mol_name: String) -> void:
	for child in molecule_detail_container.get_children():
		child.queue_free()
	
	if not simulator.molecules.has(mol_name):
		return
	
	var mol = simulator.molecules[mol_name]
	
	## Header
	var header = Label.new()
	header.text = "🧪 Molecule: %s" % mol_name
	header.add_theme_color_override("font_color", Color(0.506, 0.784, 0.514))
	header.add_theme_font_size_override("font_size", 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(header)
	
	## Current concentration
	var conc_label = Label.new()
	conc_label.name = "ConcentrationLabel"
	conc_label.text = "Concentration: %.3f mM" % mol.concentration
	conc_label.add_theme_font_size_override("font_size", 16)
	conc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(conc_label)
	
	## Find enzymes
	var producing_enzymes: Array = []
	var consuming_enzymes: Array = []
	
	for enzyme in simulator.enzymes:
		if enzyme.products.has(mol_name):
			producing_enzymes.append(enzyme)
		if enzyme.substrates.has(mol_name):
			consuming_enzymes.append(enzyme)
	
	## Producing enzymes
	if not producing_enzymes.is_empty():
		var prod_header = _create_section_label("Producing Enzymes")
		molecule_detail_container.add_child(prod_header)
		
		for enzyme in producing_enzymes:
			var stoich = enzyme.products[mol_name]
			var net_rate = enzyme.current_forward_rate - enzyme.current_reverse_rate
			var rate = net_rate * stoich
			
			var enzyme_panel = Panel.new()
			enzyme_panel.custom_minimum_size = Vector2(0, 80)
			molecule_detail_container.add_child(enzyme_panel)
			
			var vbox = VBoxContainer.new()
			vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
			enzyme_panel.add_child(vbox)
			
			var name_label = Label.new()
			name_label.text = "⚗️ %s" % enzyme.name
			name_label.add_theme_font_size_override("font_size", 14)
			vbox.add_child(name_label)
			
			var rate_label = Label.new()
			rate_label.name = "RateLabel_%s" % enzyme.id
			rate_label.text = "+%.3f mM/s (stoich: ×%.1f)" % [rate, stoich]
			rate_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			vbox.add_child(rate_label)
			
			## Add ΔG info
			var dg_label = Label.new()
			var dg_text = "ΔG: %.1f kJ/mol " % enzyme.current_delta_g
			if enzyme.current_delta_g < -5:
				dg_text += "→"
			elif enzyme.current_delta_g > 5:
				dg_text += "←"
			else:
				dg_text += "⇄"
			dg_label.text = dg_text
			var dg_color = Color.GREEN if enzyme.current_delta_g < 0 else Color.RED
			dg_label.add_theme_color_override("font_color", dg_color)
			dg_label.add_theme_font_size_override("font_size", 11)
			vbox.add_child(dg_label)
	else:
		var no_prod = Label.new()
		no_prod.text = "No enzymes producing this molecule"
		no_prod.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		molecule_detail_container.add_child(no_prod)
	
	## Consuming enzymes
	if not consuming_enzymes.is_empty():
		var cons_header = _create_section_label("Consuming Enzymes")
		molecule_detail_container.add_child(cons_header)
		
		for enzyme in consuming_enzymes:
			var stoich = enzyme.substrates[mol_name]
			var net_rate = enzyme.current_forward_rate - enzyme.current_reverse_rate
			var rate = net_rate * stoich
			
			var enzyme_panel = Panel.new()
			enzyme_panel.custom_minimum_size = Vector2(0, 80)
			molecule_detail_container.add_child(enzyme_panel)
			
			var vbox = VBoxContainer.new()
			vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
			enzyme_panel.add_child(vbox)
			
			var name_label = Label.new()
			name_label.text = "⚗️ %s" % enzyme.name
			name_label.add_theme_font_size_override("font_size", 14)
			vbox.add_child(name_label)
			
			var rate_label = Label.new()
			rate_label.name = "RateLabel_%s" % enzyme.id
			rate_label.text = "-%.3f mM/s (stoich: ×%.1f)" % [rate, stoich]
			rate_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			vbox.add_child(rate_label)
			
			## Add ΔG info
			var dg_label = Label.new()
			var dg_text = "ΔG: %.1f kJ/mol " % enzyme.current_delta_g
			if enzyme.current_delta_g < -5:
				dg_text += "→"
			elif enzyme.current_delta_g > 5:
				dg_text += "←"
			else:
				dg_text += "⇄"
			dg_label.text = dg_text
			var dg_color = Color.GREEN if enzyme.current_delta_g < 0 else Color.RED
			dg_label.add_theme_color_override("font_color", dg_color)
			dg_label.add_theme_font_size_override("font_size", 11)
			vbox.add_child(dg_label)
	else:
		var no_cons = Label.new()
		no_cons.text = "No enzymes consuming this molecule"
		no_cons.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		molecule_detail_container.add_child(no_cons)
	
	## Net rate
	var net_rate = 0.0
	for enzyme in producing_enzymes:
		var stoich = enzyme.products[mol_name]
		var enzyme_net = enzyme.current_forward_rate - enzyme.current_reverse_rate
		net_rate += enzyme_net * stoich
	for enzyme in consuming_enzymes:
		var stoich = enzyme.substrates[mol_name]
		var enzyme_net = enzyme.current_forward_rate - enzyme.current_reverse_rate
		net_rate -= enzyme_net * stoich
	
	var net_header = _create_section_label("Net Rate & Energetics")
	molecule_detail_container.add_child(net_header)
	
	var net_label = Label.new()
	net_label.name = "NetRateLabel"
	var net_sign = "+" if net_rate >= 0 else ""
	var net_color = Color(0.4, 1.0, 0.4) if net_rate >= 0 else Color(1.0, 0.4, 0.4)
	net_label.text = "%s%.3f mM/s" % [net_sign, net_rate]
	net_label.add_theme_color_override("font_color", net_color)
	net_label.add_theme_font_size_override("font_size", 16)
	net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(net_label)
	
	## Thermodynamic summary
	var trend_label = Label.new()
	trend_label.name = "TrendLabel"
	var trend_text = ""
	if abs(net_rate) < 0.01:
		trend_text = "⇄ Near steady state"
	elif net_rate > 0:
		trend_text = "↑ Concentration increasing"
	else:
		trend_text = "↓ Concentration decreasing"
	trend_label.text = trend_text
	trend_label.add_theme_font_size_override("font_size", 12)
	trend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(trend_label)
	
	## Show how many reactions are favorable
	var fav_producers = 0
	var fav_consumers = 0
	for enzyme in producing_enzymes:
		if enzyme.current_delta_g < 0:
			fav_producers += 1
	for enzyme in consuming_enzymes:
		if enzyme.current_delta_g < 0:
			fav_consumers += 1
	
	var energetics_label = Label.new()
	energetics_label.text = "⚡ Producers: %d favorable | Consumers: %d favorable" % [fav_producers, fav_consumers]
	energetics_label.add_theme_font_size_override("font_size", 11)
	energetics_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	energetics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	molecule_detail_container.add_child(energetics_label)

## ============================================================================
## UI ELEMENT CREATORS
## ============================================================================

func create_molecule_slot(enzyme: Enzyme, mol_name: String, slot_type: String, factor: float) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 40)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var label = Label.new()
	label.text = "  %s" % mol_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	## Factor slider
	if slot_type in ["substrate", "product"]:
		var stoich_label = Label.new()
		stoich_label.text = "×%.1f" % factor
		hbox.add_child(stoich_label)

		var stoich_slider = HSlider.new()
		stoich_slider.custom_minimum_size = Vector2(100, 0)
		stoich_slider.min_value = 0.1
		stoich_slider.max_value = 5.0
		stoich_slider.step = 0.1
		stoich_slider.value = factor
		stoich_slider.value_changed.connect(func(val):
			stoich_label.text = "×%.1f" % val
			if slot_type == "substrate":
				enzyme.substrates[mol_name] = val
			else:
				enzyme.products[mol_name] = val
		)
		hbox.add_child(stoich_slider)
	elif slot_type == "competitive_inhibitor":
		var ki_label = Label.new()
		ki_label.text = "Ki: %.3f mM" % factor
		hbox.add_child(ki_label)

		var ki_slider = HSlider.new()
		ki_slider.custom_minimum_size = Vector2(100, 0)
		ki_slider.min_value = 0.001
		ki_slider.max_value = 5.0
		ki_slider.step = 0.01
		ki_slider.value = factor
		ki_slider.value_changed.connect(func(val):
			ki_label.text = "Ki: %.3f mM" % val
			enzyme.competitive_inhibitors[mol_name] = val
		)
		hbox.add_child(ki_slider)

	## Remove button
	var remove_btn = Button.new()
	remove_btn.text = "✕"
	remove_btn.custom_minimum_size = Vector2(30, 30)
	remove_btn.pressed.connect(func(): 
		simulator.remove_molecule_from_enzyme(enzyme, mol_name, slot_type)
		build_enzyme_detail_view(enzyme)
	)
	hbox.add_child(remove_btn)

	return panel

func create_allosteric_slot(enzyme: Enzyme, mol_name: String, slot_type: String, params: Dictionary) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 70)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	panel.add_child(vbox)

	var hbox1 = HBoxContainer.new()
	vbox.add_child(hbox1)

	var label = Label.new()
	label.text = "  %s" % mol_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox1.add_child(label)

	var remove_btn = Button.new()
	remove_btn.text = "✕"
	remove_btn.custom_minimum_size = Vector2(30, 30)
	remove_btn.pressed.connect(func(): 
		simulator.remove_molecule_from_enzyme(enzyme, mol_name, slot_type)
		build_enzyme_detail_view(enzyme)
	)
	hbox1.add_child(remove_btn)

	## Kd slider
	var kd = params.get("kd", 0.5)
	var kd_label = Label.new()
	kd_label.text = "  Kd: %.3f mM" % kd
	vbox.add_child(kd_label)

	var kd_slider = HSlider.new()
	kd_slider.min_value = 0.01
	kd_slider.max_value = 5.0
	kd_slider.step = 0.01
	kd_slider.value = kd
	kd_slider.value_changed.connect(func(val):
		kd_label.text = "  Kd: %.3f mM" % val
		if slot_type == "allosteric_inhibitor":
			enzyme.allosteric_inhibitors[mol_name]["kd"] = val
		else:
			enzyme.allosteric_activators[mol_name]["kd"] = val
	)
	vbox.add_child(kd_slider)

	## Fold slider
	var fold = params.get("fold", 1.0)
	var fold_label = Label.new()
	fold_label.text = "  Fold: %.2f×" % fold
	vbox.add_child(fold_label)

	var fold_slider = HSlider.new()
	fold_slider.min_value = 0.1 if slot_type == "allosteric_inhibitor" else 1.0
	fold_slider.max_value = 1.0 if slot_type == "allosteric_inhibitor" else 5.0
	fold_slider.step = 0.1
	fold_slider.value = fold
	fold_slider.value_changed.connect(func(val):
		fold_label.text = "  Fold: %.2f×" % val
		if slot_type == "allosteric_inhibitor":
			enzyme.allosteric_inhibitors[mol_name]["fold"] = val
		else:
			enzyme.allosteric_activators[mol_name]["fold"] = val
	)
	vbox.add_child(fold_slider)

	return panel

func create_add_slot(enzyme: Enzyme, slot_type: String) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 40)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var label = Label.new()
	label.text = "+ Drop molecule here"
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(label)

	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and simulator.dragging_molecule != "":
			simulator.add_molecule_to_enzyme(enzyme, simulator.dragging_molecule, slot_type)
			simulator.stop_molecule_drag()
			build_enzyme_detail_view(enzyme)
	)

	return panel

func create_parameter_slider(param_name: String, initial_value: float, min_val: float, max_val: float, step_val: float, callback: Callable) -> VBoxContainer:
	var container = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "%s: %.3f" % [param_name, initial_value]
	container.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = initial_value
	slider.value_changed.connect(func(val):
		label.text = "%s: %.3f" % [param_name, val]
		callback.call(val)
	)
	container.add_child(slider)
	
	return container

func _create_section_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	return label

## ============================================================================
## DIALOGS
## ============================================================================

func show_add_molecule_dialog() -> void:
	var dialog = Window.new()
	dialog.title = "Add New Molecule"
	dialog.size = Vector2i(400, 250)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	dialog.add_child(vbox)

	var name_label = Label.new()
	name_label.text = "Molecule Name:"
	vbox.add_child(name_label)
	
	var name_input = LineEdit.new()
	name_input.placeholder_text = "e.g., glucose, ATP"
	vbox.add_child(name_input)

	var conc_label = Label.new()
	conc_label.text = "Initial Concentration (mM):"
	vbox.add_child(conc_label)
	
	var conc_input = SpinBox.new()
	conc_input.min_value = 0.0
	conc_input.max_value = 100.0
	conc_input.step = 0.1
	conc_input.value = 1.0
	vbox.add_child(conc_input)

	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(button_hbox)

	var add_btn = Button.new()
	add_btn.text = "Add"
	add_btn.custom_minimum_size = Vector2(100, 40)
	button_hbox.add_child(add_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 40)
	button_hbox.add_child(cancel_btn)

	add_btn.pressed.connect(func():
		var mol_name = name_input.text.strip_edges()
		if mol_name.is_empty():
			print("⚠️ Molecule name cannot be empty")
			return
		if simulator.molecules.has(mol_name):
			print("⚠️ Molecule '%s' already exists" % mol_name)
			return
		simulator.add_molecule(mol_name, conc_input.value)
		rebuild_molecule_list()
		dialog.queue_free()
	)

	cancel_btn.pressed.connect(func(): dialog.queue_free())
	
	add_child(dialog)
	dialog.popup_centered()
