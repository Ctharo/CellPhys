# Biochemistry Simulator - Reaction-Based System

## Overview
This is a thermodynamically-driven enzyme simulator built in Godot 4. The simulator models biochemical reactions with proper thermodynamic constraints, bidirectional reactions, and Michaelis-Menten kinetics.

## Key Features

### 1. **Reaction-Based Architecture**
- Enzymes contain an array of `Reaction` objects
- Each reaction contains all kinetic and thermodynamic parameters
- Reactions are **bidirectional** and thermodynamically constrained

### 2. **Thermodynamic Calculations**
- **ΔG° (Standard Free Energy)**: Set for each reaction
- **ΔG (Actual Free Energy)**: Calculated from concentrations using Q (reaction quotient)
- **Formula**: ΔG = ΔG° + RT ln(Q)
- **Keq (Equilibrium Constant)**: Keq = exp(-ΔG° / RT)

### 3. **Bidirectional Reactions**
- Forward rate: Substrates → Products
- Reverse rate: Products → Substrates (based on Haldane relationship)
- Net rate = Forward rate - Reverse rate
- Thermodynamic constraints:
  - Forward blocked if ΔG > +10 kJ/mol
  - Reverse blocked if ΔG < -10 kJ/mol

### 4. **System-Wide Energetics**
The UI displays:
- Total forward rate (sum of all forward reactions)
- Total reverse rate (sum of all reverse reactions)
- Total net rate (system flux)
- Sum of ΔG values across all reactions
- Count of favorable/equilibrium/unfavorable reactions

## File Structure

```
reaction.gd           - Reaction class with thermodynamics and kinetics
enzyme.gd             - Enzyme class containing reactions array
molecule.gd           - Simple molecule with concentration
enzyme_simulator.gd   - Main simulation engine
simulator_ui.gd       - UI management and display
main.gd               - Entry point
main.tscn             - Main scene
enzyme_simulator.tscn - Simulator scene
```

## Class Hierarchy

### Reaction
```gdscript
Properties:
- substrates: Dictionary {molecule: stoichiometry}
- products: Dictionary {molecule: stoichiometry}
- vmax: float (maximum velocity)
- km: float (Michaelis constant)
- delta_g: float (ΔG° in kJ/mol)
- temperature: float (default 310 K)

Runtime State:
- current_forward_rate
- current_reverse_rate
- current_delta_g_actual
- current_keq

Methods:
- calculate_keq() → float
- calculate_actual_delta_g(molecules) → float
- calculate_forward_rate(molecules, enzyme_conc) → float
- calculate_reverse_rate(molecules, enzyme_conc) → float
```

### Enzyme
```gdscript
Properties:
- name: String
- concentration: float
- reactions: Array[Reaction]
- inhibitors: Dictionary {molecule: Ki}
- activators: Dictionary {molecule: fold}
- creation_rate: float
- degradation_rate: float

Runtime State:
- current_total_forward_rate
- current_total_reverse_rate
- current_net_rate

Methods:
- add_reaction(reaction)
- update_reaction_rates(molecules)
- update_enzyme_concentration(molecules, timestep)
```

## Example Initialization

```gdscript
## Create enzyme
var hexokinase = add_enzyme_object("Hexokinase")

## Create reaction: Glucose + ATP → G6P + ADP
var hex_rxn = create_reaction("Glucose Phosphorylation")
hex_rxn.substrates["Glucose"] = 1.0
hex_rxn.substrates["ATP"] = 1.0
hex_rxn.products["G6P"] = 1.0
hex_rxn.products["ADP"] = 1.0
hex_rxn.delta_g = -16.7  ## Favorable reaction
hex_rxn.vmax = 3.0
hex_rxn.km = 0.1

## Add reaction to enzyme
hexokinase.add_reaction(hex_rxn)

## Add enzyme-level regulation
hexokinase.inhibitors["G6P"] = 0.3  ## Product inhibition
```

## Default Simulation

The simulator initializes with a simplified glycolysis pathway:

1. **Glucose Transporter** - Source of glucose
2. **Hexokinase** - Glucose + ATP → G6P + ADP
3. **Glycolysis Enzymes** - G6P + 2 ADP + 2 Pi → 2 Pyruvate + 2 ATP
4. **ATP Synthase** - ADP + Pi → ATP (unfavorable, driven by concentration gradients)
5. **ATPase** - ATP → ADP + Pi (ATP consumption)

## Thermodynamic Principles

### Michaelis-Menten Kinetics
```
v = Vmax * [S] / (Km + [S])
```

### Haldane Relationship
The reverse Vmax is related to forward Vmax by the equilibrium constant:
```
Vmax_reverse = Vmax_forward / Keq
```

### Thermodynamic Damping
- Reactions near equilibrium (ΔG ≈ 0) proceed slowly in both directions
- Favorable reactions (ΔG < 0) proceed forward rapidly
- Unfavorable reactions (ΔG > 0) are damped or blocked

### Source/Sink Reactions
- **Sources**: No substrates, constant production (e.g., glucose import)
- **Sinks**: No products, irreversible consumption
- Sources ignore thermodynamic constraints

## UI Features

### Enzyme List
- Shows enzyme name, net rate, concentration
- Direction indicators (→→, →, ⇄, ←, ←←)
- Click to view detailed information

### Enzyme Detail View
- Total forward/reverse/net rates
- Individual reaction displays with:
  - Reaction equation
  - Forward/reverse/net rates
  - ΔG (actual and standard)
  - Direction indicator
  - Keq value
- Enzyme-level regulation (inhibitors, activators)
- Adjustable parameters (creation/degradation rates)

### Molecule View
- Current concentration
- Net production/consumption rate
- List of all reactions involving the molecule
- Thermodynamic status

### System Energetics (Top Bar)
```
⚡ System: Fwd: X.XX | Rev: Y.YY | Net: Z.ZZ mM/s
  ΣΔG: W.W kJ/mol | Fav:A Eq:B Unfav:C
```

## Implementation Notes

### Why This Architecture?

1. **Modularity**: Each reaction is self-contained
2. **Thermodynamic Accuracy**: Proper ΔG calculations drive reaction direction
3. **Bidirectionality**: All reactions can reverse based on concentrations
4. **Extensibility**: Easy to add new reactions and regulatory mechanisms
5. **Realistic**: Models real biochemical behavior

### Key Algorithms

**Forward Rate Calculation**:
1. Check if enzyme concentration > 0
2. For sources: return Vmax * [E]
3. Calculate ΔG from current concentrations
4. Block if ΔG > +10 kJ/mol
5. Apply Michaelis-Menten to each substrate
6. Use minimum saturation (limiting substrate)
7. Apply thermodynamic damping if slightly unfavorable

**Reverse Rate Calculation**:
1. Skip for sources/sinks
2. Calculate ΔG
3. Block if ΔG < -10 kJ/mol
4. Calculate reverse Vmax using Haldane relationship
5. Apply Michaelis-Menten to products
6. Apply thermodynamic damping

### Constants
- R = 8.314e-3 kJ/(mol·K) (Gas constant)
- T = 310 K (37°C, physiological temperature)

## Future Enhancements

1. **More Regulation Types**:
   - Allosteric regulation per reaction
   - Cooperative binding (Hill coefficient)
   - Phosphorylation/dephosphorylation

2. **Advanced Thermodynamics**:
   - pH-dependent ΔG
   - Ionic strength effects
   - Membrane potential effects

3. **Pathway Analysis**:
   - Flux control coefficients
   - Metabolic control analysis
   - Pathway visualization

4. **Export/Import**:
   - Save/load simulation states
   - SBML format support
   - Parameter optimization

## Usage Tips

1. **Balancing the System**: Adjust Vmax values to prevent accumulation or depletion
2. **Thermodynamic Feasibility**: Ensure ΔG° values are biochemically reasonable
3. **Enzyme Concentrations**: Keep in realistic range (0.001-0.1 mM)
4. **Substrate Concentrations**: Typical range 0.1-10 mM
5. **Observation**: Watch how reactions approach equilibrium and respond to perturbations

## References

- Nelson, D. L., & Cox, M. M. (2017). *Lehninger Principles of Biochemistry*
- Cornish-Bowden, A. (2012). *Fundamentals of Enzyme Kinetics*
- Alberty, R. A. (2003). *Thermodynamics of Biochemical Reactions*
