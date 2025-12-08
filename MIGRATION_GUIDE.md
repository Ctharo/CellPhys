# Resource Architecture Migration Guide

## Overview

This refactoring converts your core data classes from `RefCounted` to `Resource`, enabling:

1. **Save/Load** - Persist interesting simulation states to `.tres` files
2. **Inspector Editing** - Design molecules and reactions visually in Godot's editor
3. **Pathway Presets** - Create and share reusable metabolic pathway templates
4. **Reactive Updates** - Resources have built-in `changed` signal

## File Mapping

| Old File | New File | Notes |
|----------|----------|-------|
| `molecule.gd` | `molecule_data.gd` | Class: `MoleculeData` |
| `enzyme.gd` | `enzyme_data.gd` | Class: `EnzymeData` |
| `reaction.gd` | `reaction_data.gd` | Class: `ReactionData` |
| `gene.gd` | `gene_data.gd` | Class: `GeneData` |
| `regulatory_element.gd` | `regulatory_element_data.gd` | Class: `RegulatoryElementData` |
| `cell.gd` | `cell_data.gd` | Class: `CellData` |
| `simulator.gd` | `simulator.gd` | Updated to use new classes |
| — | `simulation_snapshot.gd` | **NEW** - Save/load states |
| — | `pathway_preset.gd` | **NEW** - Reusable pathway templates |
| — | `pathway_browser.gd` | **NEW** - UI dialog for pathways |
| `concentration_panel.gd` | `concentration_panel.gd` | Updated for compatibility |
| `gene_panel.gd` | `gene_panel.gd` | Updated for compatibility |

## Installation

1. Copy all `.gd` files from the `resource_refactor` folder to your project root
2. You can keep your old files during transition - the new classes have different names
3. Update your `main.gd` to use the new save/load functionality (see below)

## Key API Changes

### Property Name Changes

```gdscript
# Old                           # New
molecule.name                   molecule.molecule_name
enzyme.id                       enzyme.enzyme_id
enzyme.name                     enzyme.enzyme_name
gene.name                       gene.gene_name
reaction.id                     reaction.reaction_id
reaction.name                   reaction.reaction_name
```

### Creating Instances

```gdscript
# Resources need create_instance() for runtime copies
var template: MoleculeData = preload("res://presets/glucose.tres")
var runtime_mol = template.create_instance()

# Or create directly
var mol = MoleculeData.create_random("ATP", 5.0)
```

### Save/Load Simulation State

```gdscript
# Save current state
sim_engine.save_snapshot("user://snapshots/my_save.tres", "My Discovery", "Found interesting oscillation")

# Load state
sim_engine.load_snapshot("user://snapshots/my_save.tres")
```

### Load Built-in Pathways

```gdscript
# By name
sim_engine.load_builtin_pathway("feedback_inhibition")
sim_engine.load_builtin_pathway("oscillator")
sim_engine.load_builtin_pathway("branched")

# Or from preset object
var preset = PathwayPreset.create_feedback_inhibition()
sim_engine.load_pathway(preset)
```

### Available Built-in Pathways

| Name | Description |
|------|-------------|
| `linear` | Simple A→B→C chain |
| `feedback_inhibition` | End product represses first enzyme |
| `branched` | One substrate feeds two competing pathways |
| `oscillator` | Repressilator-style oscillating system |

## Creating Custom Pathway Presets

Save your design as a `.tres` file for reuse:

```gdscript
var preset = PathwayPreset.new()
preset.pathway_name = "My Custom Pathway"
preset.description = "Demonstrates XYZ behavior"
preset.tags = ["custom", "educational"]
preset.difficulty = 2

# Add molecules
var atp = MoleculeData.create_random("ATP", 5.0)
preset.molecules.append(atp)

# Add enzymes with reactions
var kinase = EnzymeData.new("kinase_1", "MyKinase")
var rxn = ReactionData.new("rxn_1")
rxn.substrates["ATP"] = 1.0
rxn.products["ADP"] = 1.0
kinase.add_reaction(rxn)
preset.enzymes.append(kinase)

# Save
preset.save_to_file("res://presets/my_pathway.tres")
```

## Updating main.gd for Save/Load

Add these buttons to your toolbar and connect handlers:

```gdscript
# In _ready() or _create_ui():
var save_button = Button.new()
save_button.text = "💾 Save"
save_button.pressed.connect(_on_save_pressed)

var load_button = Button.new()
load_button.text = "📂 Load"
load_button.pressed.connect(_on_load_pressed)

# Handlers:
func _on_save_pressed() -> void:
    var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
    var path = "user://snapshots/sim_%s.tres" % timestamp
    sim_engine.save_snapshot(path, "Snapshot %s" % timestamp)
    print("Saved to: ", path)

func _on_load_pressed() -> void:
    var browser = PathwayBrowser.new()
    browser.pathway_selected.connect(_on_pathway_loaded)
    browser.snapshot_selected.connect(_on_snapshot_loaded)
    add_child(browser)
    browser.popup_centered()

func _on_pathway_loaded(preset: PathwayPreset) -> void:
    sim_engine.load_pathway(preset)
    _setup_panels()  # Refresh UI

func _on_snapshot_loaded(snapshot: SimulationSnapshot) -> void:
    snapshot.restore_to(sim_engine)
    _setup_panels()
```

## Backward Compatibility

The updated UI panels (`ConcentrationPanel`, `GenePanel`) automatically detect whether they're working with old `RefCounted` classes or new `Resource` classes. You can migrate incrementally.

## Inspector Editing

After adding the new files, you can:

1. Create a new Resource in the FileSystem dock
2. Choose `MoleculeData`, `EnzymeData`, etc.
3. Edit properties directly in the Inspector
4. Save as `.tres` files
5. Load them in code with `preload()` or `load()`

This is great for designing educational presets with specific parameters.
