# OpenSCAD Object Structure Documentation

## Wing Configuration Objects

This project uses OpenSCAD's experimental object feature to create a clean, hierarchical configuration system for wing parameters.

### Main Wing Configuration

```scad
main_wing_config = object(
    // Basic geometry
    sections = Main_Wing_Sections,              // Number of wing sections for resolution
    wing_mm = Main_Wing_mm,                     // Half-span length in mm
    root_chord_mm = Main_Wing_Root_Chord_MM,    // Root chord length in mm
    tip_chord_mm = Main_Wing_Tip_Chord_MM,      // Tip chord length in mm
    wing_mode = Main_Wing_Mode,                 // 1=Trapezoidal, 2=Elliptic
    elliptic_pow = Main_Wing_Eliptic_Pow,       // Elliptic power factor
    center_line_perc = MainWing_Center_Line_Perc, // Center line percentage from LE
    
    // Anhedral configuration
    anhedral = object(
        degrees = Wing_Anhedral_Degrees,        // Anhedral angle in degrees
        start_perc = Wing_Anhedral_Start_At_Percentage // Where anhedral starts (% from root)
    ),
    
    // Washout configuration  
    washout = object(
        degrees = Main_Wing_Washout_Deg,        // Washout twist in degrees
        start = Main_Wing_Washout_Start,        // Where washout starts (mm from root)
        pivot_perc = Main_Wing_Washout_Pivot_Perc // Washout pivot point (% from LE)
    ),
    
    // Airfoil transition configuration
    airfoil = object(
        tip_change_perc = tip_airfoil_change_perc,     // Where to change to tip airfoil (%)
        center_change_perc = center_airfoil_change_perc // Where to change to center airfoil (%)
    )
);
```

### Rear Wing Configuration

```scad
rear_wing_config = object(
    // Similar structure to main wing but with rear wing specific values
    // ... (same nested structure)
);
```
