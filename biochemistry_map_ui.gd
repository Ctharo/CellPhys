# ============================================================================
# INTERACTIVE BIOCHEMISTRY MAP UI
# Visual representation with draggable reaction nodes and dynamic arrows
# ============================================================================

extends Control
class_name BiochemistryMapUI

var simulator: BiochemistrySimulator
var reaction_nodes: Dictionary = {}  # {"reaction_id": ReactionNode}
var selected_node: ReactionNode = null
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var timestep: float = 0.05
var is_paused: bool = false
var show_details: bool = false

class ReactionNode:
	"""Visual representation of a reaction"""
	var reaction: BiochemistrySimulator.Reaction
	var position: Vector2
	var size: Vector2 = Vector2(120, 100)
	var is_hovered: bool = false
	var is_selected: bool = false
	var rate: float = 0.0
	var details_expanded: bool = false
	
	func _init(p_reaction: BiochemistrySimulator.Reaction) -> void:
		reaction = p_reaction
		position = Vector2(randf_range(50, 900), randf_range(50, 600))
	
	func contains_point(p: Vector2) -> bool:
		return Rect2(position, size).has_point(p)
	
	func get_rect() -> Rect2:
		return Rect2(position, size)

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	## Initialize simulator
	simulator = BiochemistrySimulator.new()
	add_child(simulator)
	
	## Add background
	var bg = ColorRect.new()
	bg.color = Color.from_string("#0f1419", Color.BLACK)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	move_child(bg, 0)
	
	## Create reaction nodes
	for rxn in simulator.reactions:
		var node = ReactionNode.new(rxn)
		reaction_nodes[rxn.id] = node
	
	print("🧬 Biochemistry Map UI Ready!")
	_print_controls()

## Prints available keyboard controls to console
func _print_controls() -> void:
	print("\n📋 CONTROLS:")
	print("  LMB - Click & drag reaction nodes")
	print("  Click reaction - Show/hide details")
	print("  [SPACE] - Add glucose")
	print("  [O] - Hypoxia")
	print("  [P] - Pause/Resume")
	print("  [R] - Reset")

func _process(delta: float) -> void:
	if not is_paused:
		simulator.total_time += delta
		if fmod(simulator.total_time, timestep) < delta:
			simulator.simulate_step()
			simulator.iteration += 1
	
	_handle_input()
	queue_redraw()

## Processes keyboard and mouse input
func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if selected_node and selected_node.is_hovered:
			selected_node.details_expanded = !selected_node.details_expanded
		else:
			show_details = !show_details
	
	if Input.is_key_pressed(KEY_SPACE):
		simulator.set_molecule_conc("glucose", simulator.get_molecule_conc("glucose") + 0.1)
	
	if Input.is_key_pressed(KEY_O):
		simulator.set_molecule_conc("oxygen", 0.01)
	
	if Input.is_key_pressed(KEY_P):
		if Input.is_key_pressed(KEY_P):
			is_paused = !is_paused
	
	if Input.is_key_pressed(KEY_R):
		simulator.initialize_molecules()

## Handles mouse and input events for node interaction
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			## Check if clicking on a node
			for node_id in reaction_nodes:
				var node = reaction_nodes[node_id]
				if node.contains_point(event.position):
					selected_node = node
					dragging = true
					drag_offset = event.position - node.position
					get_tree().set_input_as_handled()
					return
			selected_node = null
		
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = false
	
	if event is InputEventMouseMotion and dragging and selected_node:
		selected_node.position = event.position - drag_offset
		selected_node.position.x = clamp(selected_node.position.x, 0, get_rect().size.x - selected_node.size.x)
		selected_node.position.y = clamp(selected_node.position.y, 0, get_rect().size.y - selected_node.size.y)

## Main draw function for rendering the biochemistry map
func _draw() -> void:
	var viewport_size = get_rect().size
	
	## Draw compartments background
	_draw_compartment_backgrounds()
	
	## Draw connecting arrows (behind nodes)
	_draw_metabolic_arrows()
	
	## Draw reaction nodes
	for node_id in reaction_nodes:
		var node = reaction_nodes[node_id]
		
		## Update hover state
		node.is_hovered = node.contains_point(get_local_mouse_position())
		node.is_selected = (node == selected_node)
		node.rate = simulator.get_reaction_rate(node.reaction.id)
		
		_draw_reaction_node(node)
	
	## Draw title
	draw_string(ThemeDB.fallback_font, Vector2(20, 20), "🧬 BIOCHEMISTRY MAP", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	
	## Draw status bar
	var status = "⏸️ PAUSED" if is_paused else "▶️ RUNNING"
	draw_string(ThemeDB.fallback_font, Vector2(20, 60), status, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW if is_paused else Color.GREEN)
	
	## Draw selected node details
	if selected_node and selected_node.details_expanded:
		_draw_node_details(selected_node)

## Draws background rectangles for organelle compartments
func _draw_compartment_backgrounds() -> void:
	var compartments = simulator.compartments
	
	var cyto_rect = Rect2(Vector2(20, 100), Vector2(960, 400))
	draw_rect(cyto_rect, Color.from_string("#1a2332", Color.BLACK), true)
	draw_rect(cyto_rect, Color.LIGHT_GRAY.lerp(Color.BLACK, 0.7), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(30, 115), "CYTOPLASM", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.LIGHT_GRAY)
	
	var mito_rect = Rect2(Vector2(40, 130), Vector2(500, 300))
	draw_rect(mito_rect, Color.ORANGE.lerp(Color.BLACK, 0.85), true)
	draw_rect(mito_rect, Color.ORANGE.lerp(Color.BLACK, 0.5), false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(50, 145), "MITOCHONDRION", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.ORANGE)

## Renders a single reaction node with activity indicator
func _draw_reaction_node(node: ReactionNode) -> void:
	var rect = node.get_rect()
	
	## Background color based on rate intensity
	var rate_intensity = clamp(node.rate / 25.0, 0.0, 1.0)
	var base_color = Color.from_string("#2a3f5f", Color.DARK_GRAY)
	var active_color = Color.CYAN
	var bg_color = base_color.lerp(active_color, rate_intensity * 0.5)
	
	## Border color
	var border_color = Color.WHITE
	if node.is_selected:
		border_color = Color.YELLOW
	elif node.is_hovered:
		border_color = Color.LIGHT_BLUE
	
	## Draw background
	draw_rect(rect, bg_color, true)
	draw_rect(rect, border_color, false, 2.0 if node.is_selected else 1.0)
	
	## Draw enzyme name
	var text_pos = node.position + Vector2(5, 15)
	draw_string(ThemeDB.fallback_font, text_pos, node.reaction.enzyme, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	## Draw rate bar
	var bar_rect = Rect2(node.position + Vector2(5, 50), Vector2(110, 8))
	draw_rect(bar_rect, Color.BLACK, true)
	
	var fill_width = bar_rect.size.x * rate_intensity
	var fill_rect = Rect2(bar_rect.position, Vector2(fill_width, bar_rect.size.y))
	var fill_color = Color.BLUE.lerp(Color.RED, rate_intensity)
	draw_rect(fill_rect, fill_color, true)
	draw_rect(bar_rect, Color.GRAY, false, 1.0)
	
	## Draw rate value
	draw_string(ThemeDB.fallback_font, node.position + Vector2(5, 65), 
				"%.2f" % node.rate, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)

## Draws connecting arrows between reactions based on shared molecules
func _draw_metabolic_arrows() -> void:
	var drawn_arrows = {}
	
	for rxn_id in reaction_nodes:
		var source_node = reaction_nodes[rxn_id]
		var source_rxn = source_node.reaction
		
		## Find reactions that consume products of this reaction
		for target_id in reaction_nodes:
			if target_id == rxn_id:
				continue
			
			var target_node = reaction_nodes[target_id]
			var target_rxn = target_node.reaction
			
			## Check if target consumes any products of source
			for product_name in source_rxn.products:
				if product_name in target_rxn.reactants:
					var arrow_key = "%s->%s" % [rxn_id, target_id]
					if arrow_key not in drawn_arrows:
						drawn_arrows[arrow_key] = true
						
						## Get molecule concentration for arrow thickness
						var mol_conc = simulator.get_molecule_conc(product_name)
						var rate = simulator.get_reaction_rate(rxn_id)
						
						_draw_connection_arrow(source_node, target_node, product_name, rate, mol_conc)

## Renders an arrow connecting two reaction nodes with dynamic styling
func _draw_connection_arrow(from_node: ReactionNode, to_node: ReactionNode, 
						   product_name: String, rate: float, conc: float) -> void:
	
	var from_center = from_node.position + from_node.size / 2.0
	var to_center = to_node.position + to_node.size / 2.0
	
	## Calculate direction and find edge points
	var direction = (to_center - from_center).normalized()
	var from_edge = from_node.position + from_node.size / 2.0 + direction * 60
	var to_edge = to_node.position + to_node.size / 2.0 - direction * 60
	
	## Normalize rate for thickness (0-5 pixels)
	var rate_normalized = clamp(rate / 25.0, 0.0, 1.0)
	var thickness = lerp(1.0, 5.0, rate_normalized)
	
	## Arrow color based on rate intensity (blue -> cyan -> yellow -> red)
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
	
	## Draw concentration value
	draw_string(ThemeDB.fallback_font, mid + Vector2(0, 12), "%.3f mM" % conc, 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color.LIGHT_GRAY)

## Displays detailed information panel for selected reaction
func _draw_node_details(node: ReactionNode) -> void:
	var detail_pos = node.position + Vector2(node.size.x + 20, 0)
	var detail_width = 300.0
	var detail_height = 400.0
	
	## Clamp to screen
	detail_pos.x = min(detail_pos.x, get_rect().size.x - detail_width - 20)
	
	var detail_rect = Rect2(detail_pos, Vector2(detail_width, detail_height))
	
	## Draw panel background
	draw_rect(detail_rect, Color.from_string("#1a2332", Color.BLACK), true)
	draw_rect(detail_rect, Color.CYAN, false, 2.0)
	
	var text_y = detail_pos.y + 15
	var line_height = 20
	var font = ThemeDB.fallback_font
	
	## Title
	draw_string(font, Vector2(detail_pos.x + 10, text_y), node.reaction.name, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW)
	text_y += line_height * 1.5
	
	## Enzyme
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Enzyme: %s" % node.reaction.enzyme, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	text_y += line_height
	
	## Compartment
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Location: %s" % node.reaction.compartment, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.LIGHT_GRAY)
	text_y += line_height * 1.5
	
	## Current rate
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Current Rate:", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.CYAN)
	text_y += line_height
	draw_string(font, Vector2(detail_pos.x + 20, text_y), "%.4f μmol/min" % node.rate, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)
	text_y += line_height * 1.5
	
	## Reactants
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Reactants:", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_GREEN)
	text_y += line_height
	
	for reactant_name in node.reaction.reactants:
		var stoich = node.reaction.reactants[reactant_name]
		var conc = simulator.get_molecule_conc(reactant_name)
		var display_name = simulator.molecules[reactant_name].name if simulator.molecules.has(reactant_name) else reactant_name
		draw_string(font, Vector2(detail_pos.x + 20, text_y), "%s (%.3f mM)" % [display_name, conc], 
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		text_y += line_height
	
	text_y += 5
	
	## Products
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Products:", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_GREEN)
	text_y += line_height
	
	for product_name in node.reaction.products:
		var stoich = node.reaction.products[product_name]
		var conc = simulator.get_molecule_conc(product_name)
		var display_name = simulator.molecules[product_name].name if simulator.molecules.has(product_name) else product_name
		draw_string(font, Vector2(detail_pos.x + 20, text_y), "%s (%.3f mM)" % [display_name, conc], 
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		text_y += line_height

## Returns display name for compartment identifier
func _get_compartment_display_name(comp: String) -> String:
	match comp:
		"cytoplasm":
			return "Cytoplasm"
		"mitochondrion":
			return "Mitochondrial Matrix"
		"extracellular":
			return "Extracellular"
		_:
			return comp

func draw_node_details(node: ReactionNode) -> void:
	"""Draw detailed panel for selected reaction"""
	var detail_pos = node.position + Vector2(node.size.x + 20, 0)
	var detail_width = 300.0
	var detail_height = 400.0
	
	# Clamp to screen
	detail_pos.x = min(detail_pos.x, get_rect().size.x - detail_width - 20)
	
	var detail_rect = Rect2(detail_pos, Vector2(detail_width, detail_height))
	
	# Draw panel background
	draw_rect(detail_rect, Color.from_string("#1a2332", Color.BLACK), true)
	draw_rect(detail_rect, Color.CYAN, false, 2.0)
	
	var text_y = detail_pos.y + 15
	var line_height = 20
	var font = ThemeDB.fallback_font
	
	# Title
	draw_string(font, Vector2(detail_pos.x + 10, text_y), node.reaction.name, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW)
	text_y += line_height * 1.5
	
	# Enzyme
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Enzyme: %s" % node.reaction.enzyme, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	text_y += line_height
	
	# Compartment
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Location: %s" % node.reaction.compartment, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.LIGHT_GRAY)
	text_y += line_height * 1.5
	
	# Current rate
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Current Rate:", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.CYAN)
	text_y += line_height
	draw_string(font, Vector2(detail_pos.x + 20, text_y), "%.4f μmol/min" % node.rate, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)
	text_y += line_height * 1.5
	
	# Reactants
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Reactants:", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_GREEN)
	text_y += line_height
	
	for reactant_name in node.reaction.reactants:
		var stoich = node.reaction.reactants[reactant_name]
		var conc = simulator.get_molecule_conc(reactant_name)
		var display_name = simulator.molecules[reactant_name].name if simulator.molecules.has(reactant_name) else reactant_name
		draw_string(font, Vector2(detail_pos.x + 20, text_y), "%s (%.3f mM)" % [display_name, conc], 
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		text_y += line_height
	
	text_y += 5
	
	# Products
	draw_string(font, Vector2(detail_pos.x + 10, text_y), "Products:", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_GREEN)
	text_y += line_height
	
	for product_name in node.reaction.products:
		var stoich = node.reaction.products[product_name]
		var conc = simulator.get_molecule_conc(product_name)
		var display_name = simulator.molecules[product_name].name if simulator.molecules.has(product_name) else product_name
		draw_string(font, Vector2(detail_pos.x + 20, text_y), "%s (%.3f mM)" % [display_name, conc], 
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		text_y += line_height

func get_compartment_display_name(comp: String) -> String:
	match comp:
		"cytoplasm":
			return "Cytoplasm"
		"mitochondrion":
			return "Mitochondrial Matrix"
		"extracellular":
			return "Extracellular"
		_:
			return comp
