## Enzyme-centric interactive biochemistry map UI
## Visualizes enzymes as the primary agents of metabolic transformation

extends Control
class_name BiochemistryMapUI

var simulator: BiochemistrySimulator
var enzyme_nodes: Dictionary = {}  ## {"enzyme_id": EnzymeNode}
var selected_node: EnzymeNode = null
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var timestep: float = 0.05
var is_paused: bool = false

class EnzymeNode:
	## Visual representation of an enzyme
	var enzyme: BiochemistrySimulator.Enzyme
	var position: Vector2
	var size: Vector2 = Vector2(140, 120)
	var is_hovered: bool = false
	var is_selected: bool = false
	var details_expanded: bool = false
	
	func _init(p_enzyme: BiochemistrySimulator.Enzyme) -> void:
		enzyme = p_enzyme
		position = Vector2(randf_range(50, 900), randf_range(50, 600))
	
	func contains_point(p: Vector2) -> bool:
		return Rect2(position, size).has_point(p)
	
	func get_rect() -> Rect2:
		return Rect2(position, size)

func _init(p_simulator:BiochemistrySimulator) -> void:
	simulator = p_simulator

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	## Add background
	var bg = ColorRect.new()
	bg.color = Color.from_string("#0f1419", Color.BLACK)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	move_child(bg, 0)
		
	## Create enzyme nodes
	for enzyme in simulator.enzymes:
		var node = EnzymeNode.new(enzyme)
		enzyme_nodes[enzyme.id] = node
	
	print("🧬 Enzyme-Centric Map UI Ready!")
	_print_controls()

func _print_controls() -> void:
	print("\n🎮 CONTROLS:")
	print("  LMB - Click & drag enzyme nodes")
	print("  Click enzyme - Show/hide details")
	print("  [SPACE] - Add glucose")
	print("  [O] - Hypoxia (reduce oxygen)")
	print("  [P] - Pause/Resume")
	print("  [R] - Reset")
	print("  [E] - Toggle enzyme activity")

func _process(delta: float) -> void:
	if not is_paused:
		simulator.total_time += delta
		if fmod(simulator.total_time, timestep) < delta:
			simulator.simulate_step()
			simulator.iteration += 1
	
	_handle_input()
	queue_redraw()

func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if selected_node and selected_node.is_hovered:
			selected_node.details_expanded = !selected_node.details_expanded
	
	if Input.is_key_pressed(KEY_SPACE):
		simulator.set_molecule_conc("glucose", simulator.get_molecule_conc("glucose") + 0.1)
	
	if Input.is_key_pressed(KEY_O):
		simulator.set_molecule_conc("oxygen", 0.01)
	
	if Input.is_key_pressed(KEY_P):
		is_paused = !is_paused
	
	if Input.is_key_pressed(KEY_R):
		simulator.initialize_molecules()
	
	if Input.is_key_pressed(KEY_E):
		if selected_node:
			selected_node.enzyme.is_active = !selected_node.enzyme.is_active

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for node_id in enzyme_nodes:
				var node = enzyme_nodes[node_id]
				if node.contains_point(event.position):
					selected_node = node
					dragging = true
					drag_offset = event.position - node.position
					return
			selected_node = null
		
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = false
	
	if event is InputEventMouseMotion and dragging and selected_node:
		selected_node.position = event.position - drag_offset
		selected_node.position.x = clamp(selected_node.position.x, 0, get_rect().size.x - selected_node.size.x)
		selected_node.position.y = clamp(selected_node.position.y, 0, get_rect().size.y - selected_node.size.y)

func _draw() -> void:
	var viewport_size = get_rect().size
	
	## Draw compartment backgrounds
	_draw_compartment_backgrounds()
	
	## Draw substrate-product arrows (behind nodes)
	_draw_metabolic_arrows()
	
	## Draw enzyme nodes
	for node_id in enzyme_nodes:
		var node = enzyme_nodes[node_id]
		node.is_hovered = node.contains_point(get_local_mouse_position())
		node.is_selected = (node == selected_node)
		_draw_enzyme_node(node)
	
	## Draw title
	draw_string(ThemeDB.fallback_font, Vector2(20, 20), "🧬 ENZYME-CENTRIC METABOLISM", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	
	## Draw status bar
	var status = "⸸ PAUSED" if is_paused else "▶ RUNNING"
	draw_string(ThemeDB.fallback_font, Vector2(20, 60), status, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW if is_paused else Color.GREEN)
	
	## Draw selected enzyme details
	if selected_node and selected_node.details_expanded:
		_draw_enzyme_details(selected_node)

func _draw_compartment_backgrounds() -> void:
	## Cytoplasm
	var cyto_rect = Rect2(Vector2(20, 100), Vector2(960, 400))
	draw_rect(cyto_rect, Color.from_string("#1a2332", Color.BLACK), true)
	draw_rect(cyto_rect, Color.LIGHT_GRAY.lerp(Color.BLACK, 0.7), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(30, 115), "CYTOPLASM", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.LIGHT_GRAY)
	
	## Mitochondrion
	var mito_rect = Rect2(Vector2(40, 130), Vector2(500, 300))
	draw_rect(mito_rect, Color.ORANGE.lerp(Color.BLACK, 0.85), true)
	draw_rect(mito_rect, Color.ORANGE.lerp(Color.BLACK, 0.5), false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(50, 145), "MITOCHONDRION", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.ORANGE)

func _draw_enzyme_node(node: EnzymeNode) -> void:
	var rect = node.get_rect()
	var enzyme = node.enzyme
	
	## Color based on enzyme activity state and saturation
	var base_color = Color.from_string("#2a3f5f", Color.DARK_GRAY)
	var active_color = Color.CYAN
	var saturation = enzyme.substrate_saturation
	
	var bg_color: Color
	if not enzyme.is_active:
		bg_color = Color.from_string("#1a1a2e", Color.DARK_GRAY)
	else:
		bg_color = base_color.lerp(active_color, saturation * 0.6)
	
	## Border: yellow if selected, light blue if hovered, white if active
	var border_color = Color.WHITE
	if node.is_selected:
		border_color = Color.YELLOW
	elif node.is_hovered:
		border_color = Color.LIGHT_BLUE
	elif not enzyme.is_active:
		border_color = Color.DARK_RED
	
	## Draw background
	draw_rect(rect, bg_color, true)
	draw_rect(rect, border_color, false, 2.0 if node.is_selected else 1.0)
	
	## Draw enzyme name
	var text_pos = node.position + Vector2(5, 12)
	var name_size = 11
	draw_string(ThemeDB.fallback_font, text_pos, enzyme.name, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color.WHITE)
	
	## Draw active status
	var status_icon = "✓" if enzyme.is_active else "✗"
	var status_color = Color.GREEN if enzyme.is_active else Color.RED
	draw_string(ThemeDB.fallback_font, node.position + Vector2(110, 12), status_icon, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, status_color)
	
	## Draw saturation bar
	var bar_rect = Rect2(node.position + Vector2(5, 50), Vector2(130, 10))
	draw_rect(bar_rect, Color.BLACK, true)
	
	var fill_width = bar_rect.size.x * enzyme.substrate_saturation
	var fill_rect = Rect2(bar_rect.position, Vector2(fill_width, bar_rect.size.y))
	var fill_color = Color.BLUE.lerp(Color.RED, enzyme.substrate_saturation)
	draw_rect(fill_rect, fill_color, true)
	draw_rect(bar_rect, Color.GRAY, false, 1.0)
	
	## Draw saturation percentage
	draw_string(ThemeDB.fallback_font, node.position + Vector2(5, 63), 
				"%.0f%% sat" % (enzyme.substrate_saturation * 100.0), 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.YELLOW)
	
	## Draw current reaction rate
	draw_string(ThemeDB.fallback_font, node.position + Vector2(5, 80), 
				"%.2f µmol/min" % enzyme.current_rate, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.CYAN)
	
	## Draw Vmax indicator
	var vmax = enzyme.get_effective_vmax(1.0)
	draw_string(ThemeDB.fallback_font, node.position + Vector2(5, 95), 
				"Vmax: %.1f" % vmax, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.LIGHT_GRAY)

func _draw_metabolic_arrows() -> void:
	var drawn_arrows = {}
	
	for enzyme_id in enzyme_nodes:
		var source_node = enzyme_nodes[enzyme_id]
		var source_enzyme = source_node.enzyme
		
		## Find enzymes that consume products of this enzyme
		for target_id in enzyme_nodes:
			if target_id == enzyme_id:
				continue
			
			var target_node = enzyme_nodes[target_id]
			var target_enzyme = target_node.enzyme
			
			## Check if target consumes any products of source
			for product_name in source_enzyme.products:
				if product_name in target_enzyme.substrates:
					var arrow_key = "%s->%s" % [enzyme_id, target_id]
					if arrow_key not in drawn_arrows:
						drawn_arrows[arrow_key] = true
						
						var mol_conc = simulator.get_molecule_conc(product_name)
						var rate = source_enzyme.current_rate
						
						_draw_connection_arrow(source_node, target_node, product_name, rate, mol_conc)

func _draw_connection_arrow(from_node: EnzymeNode, to_node: EnzymeNode, 
						   product_name: String, rate: float, conc: float) -> void:
	
	var from_center = from_node.position + from_node.size / 2.0
	var to_center = to_node.position + to_node.size / 2.0
	
	var direction = (to_center - from_center).normalized()
	var from_edge = from_node.position + from_node.size / 2.0 + direction * 70
	var to_edge = to_node.position + to_node.size / 2.0 - direction * 70
	
	## Normalize rate for thickness
	var rate_normalized = clamp(rate / 25.0, 0.0, 1.0)
	var thickness = lerp(1.0, 5.0, rate_normalized)
	
	## Arrow color: blue -> cyan -> yellow -> red based on activity
	var arrow_color: Color
	if rate_normalized < 0.33:
		arrow_color = Color.BLUE.lerp(Color.CYAN, rate_normalized * 3.0)
	elif rate_normalized < 0.66:
		arrow_color = Color.CYAN.lerp(Color.YELLOW, (rate_normalized - 0.33) * 3.0)
	else:
		arrow_color = Color.YELLOW.lerp(Color.RED, (rate_normalized - 0.66) * 3.0)
	
	## Draw arrow line
	draw_line(from_edge, to_edge, arrow_color, thickness)
	
	## Draw arrowhead
	var arrow_size = thickness * 4
	var perp = Vector2(-direction.y, direction.x)
	
	var tip = to_edge
	var base_left = to_edge - direction * arrow_size + perp * arrow_size
	var base_right = to_edge - direction * arrow_size - perp * arrow_size
	
	var arrow_points = PackedVector2Array([tip, base_left, base_right])
	draw_colored_polygon(arrow_points, arrow_color)
	
	## Draw product label
	var mid = (from_edge + to_edge) / 2.0
	draw_string(ThemeDB.fallback_font, mid, product_name, 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 10, arrow_color)
	
	## Draw concentration
	draw_string(ThemeDB.fallback_font, mid + Vector2(0, 12), "%.3f mM" % conc, 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color.LIGHT_GRAY)

func _draw_enzyme_details(node: EnzymeNode) -> void:
	var enzyme = node.enzyme
	var detail_pos = node.position + Vector2(node.size.x + 20, 0)
	var detail_width = 320.0
	var detail_height = 480.0
	
	## Clamp to screen
	detail_pos.x = min(detail_pos.x, get_rect().size.x - detail_width - 20)
	
	var detail_rect = Rect2(detail_pos, Vector2(detail_width, detail_height))
	
	## Draw panel background
	draw_rect(detail_rect, Color.from_string("#1a2332", Color.BLACK), true)
	draw_rect(detail_rect, Color.CYAN, false, 2.0)
	
	var text_y = detail_pos.y + 15
	var line_height = 18
	var font = ThemeDB.fallback_font
	
	## Title
	draw_string(font, Vector2(detail_pos.x + 10, text_y), enzyme.name, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW)
	text_y += line_height * 1.5
	
	## Compartment
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Location: %s" % enzyme.compartment, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.LIGHT_GRAY)
	text_y += line_height
	
	## Active status
	var active_text = "STATUS: ACTIVE ✓" if enzyme.is_active else "STATUS: INACTIVE ✗"
	var active_color = Color.GREEN if enzyme.is_active else Color.RED
	draw_string(font, Vector2(detail_pos.x + 10, text_y), active_text, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, active_color)
	text_y += line_height
	
	## Enzyme concentration
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Enzyme conc: %.4f µM" % enzyme.concentration, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.LIGHT_GRAY)
	text_y += line_height * 1.5
	
	## Kinetic parameters
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "KINETICS:", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.CYAN)
	text_y += line_height
	
	var vmax = enzyme.get_effective_vmax(1.0)
	draw_string(font, Vector2(detail_pos.x + 20, text_y), "Vmax: %.2f µmol/min" % vmax, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	text_y += line_height
	
	draw_string(font, Vector2(detail_pos.x + 20, text_y), "Current rate: %.4f µmol/min" % enzyme.current_rate, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)
	text_y += line_height
	
	draw_string(font, Vector2(detail_pos.x + 20, text_y), "Saturation: %.1f%%" % (enzyme.substrate_saturation * 100.0), 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.CYAN)
	text_y += line_height * 1.5
	
	## Substrates
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "SUBSTRATES:", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_GREEN)
	text_y += line_height
	
	for substrate_name in enzyme.substrates:
		var conc = simulator.get_molecule_conc(substrate_name)
		var km = enzyme.km_values.get(substrate_name, 0.1)
		var display_name = simulator.molecules[substrate_name].name if simulator.molecules.has(substrate_name) else substrate_name
		var stoich = enzyme.substrates[substrate_name]
		
		draw_string(font, Vector2(detail_pos.x + 20, text_y), "%s (%.3f mM)" % [display_name, conc], 
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		text_y += line_height * 0.8
		draw_string(font, Vector2(detail_pos.x + 30, text_y), "Km: %.3f, stoich: %.1f" % [km, stoich], 
					HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.DARK_GRAY)
		text_y += line_height
	
	text_y += 5
	
	## Products
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "PRODUCTS:", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_GREEN)
	text_y += line_height
	
	for product_name in enzyme.products:
		var conc = simulator.get_molecule_conc(product_name)
		var display_name = simulator.molecules[product_name].name if simulator.molecules.has(product_name) else product_name
		var stoich = enzyme.products[product_name]
		
		draw_string(font, Vector2(detail_pos.x + 20, text_y), "%s (%.3f mM)" % [display_name, conc], 
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		text_y += line_height * 0.8
		draw_string(font, Vector2(detail_pos.x + 30, text_y), "stoich: %.1f" % stoich, 
					HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.DARK_GRAY)
		text_y += line_height
	
	text_y += 5
	
	## Regulatory info
	if enzyme.allosteric_activators.size() > 0 or enzyme.allosteric_inhibitors.size() > 0:
		draw_string(font, Vector2(detail_pos.x + 10, text_y), "REGULATION:", 
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_CYAN)
		text_y += line_height
		
		for activator in enzyme.allosteric_activators:
			draw_string(font, Vector2(detail_pos.x + 20, text_y), "▲ %s (activator)" % activator, 
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.GREEN)
			text_y += line_height
		
		for inhibitor in enzyme.allosteric_inhibitors:
			draw_string(font, Vector2(detail_pos.x + 20, text_y), "▼ %s (inhibitor)" % inhibitor, 
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.RED)
			text_y += line_height
