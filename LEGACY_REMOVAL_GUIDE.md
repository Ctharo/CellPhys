# Legacy Class Removal Guide

## Files to DELETE (Legacy RefCounted Classes)

These files contain the old RefCounted-based classes that are now replaced by Resource-based Data classes:

```
scripts/core/gene.gd           → DELETE (replaced by gene_data.gd)
scripts/core/enzyme.gd         → DELETE (replaced by enzyme_data.gd)  
scripts/core/molecule.gd       → DELETE (replaced by molecule_data.gd)
scripts/core/cell.gd           → DELETE (replaced by cell_data.gd)
scripts/core/reaction.gd       → DELETE (replaced by reaction_data.gd)
scripts/core/regulatory_element.gd → DELETE (replaced by regulatory_element_data.gd)
```

## Files to KEEP (Resource-based Data Classes)

These are the new classes that should be used exclusively:

```
scripts/core/gene_data.gd              - GeneData
scripts/core/enzyme_data.gd            - EnzymeData
scripts/core/molecule_data.gd          - MoleculeData
scripts/core/cell_data.gd              - CellData
scripts/core/reaction_data.gd          - ReactionData
scripts/core/regulatory_element_data.gd - RegulatoryElementData
```

## New Files to ADD

```
simulation_config.gd           - SimulationConfig (generation settings)
simulation_settings_dialog.gd  - SimulationSettingsDialog (UI)
pathway_generator.gd           - PathwayGenerator (creates entities from config)
simulator.gd                   - Updated Simulator (uses only Data classes)
```

## Code Migration Checklist

After deleting legacy files, search your codebase for these patterns and update:

### Class References
```gdscript
# OLD → NEW
Gene           → GeneData
Enzyme         → EnzymeData
Molecule       → MoleculeData
Cell           → CellData
Reaction       → ReactionData
RegulatoryElement → RegulatoryElementData
```

### Property Names
```gdscript
# OLD → NEW
molecule.name      → molecule.molecule_name
enzyme.id          → enzyme.enzyme_id
enzyme.name        → enzyme.enzyme_name
gene.name          → gene.gene_name
reaction.id        → reaction.reaction_id
reaction.name      → reaction.reaction_name
```

### Type Hints
```gdscript
# OLD
var my_gene: Gene
var my_enzyme: Enzyme

# NEW
var my_gene: GeneData
var my_enzyme: EnzymeData
```

## Integration Steps

1. Delete the legacy files listed above
2. Copy the new files to your scripts directory
3. Update `simulator.gd` with the new version
4. Search and replace class names in your codebase
5. Update any type hints
6. Connect SimulationSettingsDialog to your main UI

### Example main.gd Integration

```gdscript
# Add member variable
var settings_dialog: SimulationSettingsDialog = null

# In _ready():
func _setup_settings_dialog() -> void:
    settings_dialog = SimulationSettingsDialog.new()
    settings_dialog.config_applied.connect(_on_config_applied)
    add_child(settings_dialog)

# Add to View menu or create Settings button:
func _on_settings_pressed() -> void:
    settings_dialog.show_dialog()

# Handle config application:
func _on_config_applied(config: SimulationConfig) -> void:
    sim_engine.apply_config(config)
    _setup_panels()  # Refresh UI
    _update_pause_button()
```

## Verification

After migration, run the project and verify:
- [ ] No "class not found" errors
- [ ] Simulation starts and runs
- [ ] Settings dialog opens and saves profiles
- [ ] Builtin pathways load correctly
- [ ] Custom profiles can be created and deleted
- [ ] Snapshots save and load properly
