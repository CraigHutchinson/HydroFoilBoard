include <BOSL2/std.scad>
include <BOSL2/joiners.scad>

// Module for root airfoil polygon
// TODO: e817 looks good but not in DB presently
include <lib/openscad-airfoil/e/e818.scad>


// HYDROFOIL BOARD WING GENERATOR
// RC wing generator for Vase mode printing
//
// Prior work used to create this script:
// https://www.thingiverse.com/thing:3506692
// https://github.com/guillaumef/openscad-airfoil
// https://github.com/Beachless/Vase-Wing

/* [Print Settings] */
Printer_BuildArea = [250, 250, 250]; // Printer build area in mm
Printer_NozzleDiameter = 0.4; // Printer nozzle diameter in mm
Printer_MinimumWallFraction = 0.65; // Minimum wall thickness for printing as fraction of nozzle diameter

// Minimum trailing edge thickness for 3D printing compatibility
Trailing_Edge_Thickness = 2 * (Printer_NozzleDiameter * Printer_MinimumWallFraction); // mm

/* [Global Rendering Settings] */
// 360deg/2(faceAngle) = 180 facets (affects performance and object smoothness)
Render_Mode_Facet_Angle = 2.0; // [0.1:0.1:10]
// Minimum facet size for rendering (NOTE: coarse value is udef for preview mode)
Render_Mode_Facet_Size = 0.4; // [0.01:0.01:1.0]

// TODO: FixMe-Hang hollow-wing .. Enable using fast airfoil rendering mode (uses pre-computed paths for performance)
Render_Mode_Fast_PrecomputeAeroFoil = true; // [true:false]

// Enable using lower detail aerofoil rendering mode (uses fewer points for performance)
Render_Mode_Fast_ResampleAeroFoil = false; // [true:false]  

// Enable using fast wing slices rendering mode (uses fewer wing slices for performance)
Render_Mode_Fast_WingSlices = false; // [true:false]

// Enable using lower resolution primitive facets for performance
Render_Mode_Fast_Facets = false; // [true:false]

$fa = (Render_Mode_Fast_Facets || $preview) ? 10 : Render_Mode_Facet_Angle;            // 360deg/5($fa) = 60 facets (affects performance and object smoothness)
$fs = (Render_Mode_Fast_Facets || $preview) ? 1 : Render_Mode_Facet_Size;       // Min facet size (lower for final render)

/* [Build Configuration] */
// Render test parts for checking 3D printing settings
// This will create a test part for each component to check printability and settings
Build_TestParts = false; // [true:false]
Build_CalibrationParts = false; // [true:false]

// Preview mode: view Complete model built
Preview_BuiltModel = true; // [true:false]

// Scale factor (1/3.33 for 1.5 rods, 5/3.33 = 1.5 rods) 
Build_Scale = 1.0; // [0.1:0.1:3.0] 

/* [Spar Configuration] */

Spar_Rod_Small_Diameter = 2.0;
Spar_Rod_Large_Diameter = 4.0;

// Stage-1: Set to `undef` to perform quick 10-step hole calibration (~30minute print) to identify hole 0 through 10
// Stage-2: Set the best-fit value `spar_calibration_*_hole_result` for a long print-volume spar hole calibration (~8hour print)

// NOTE: The absolute tolerance shall be printed when `Build_CalibrationParts` is enabled
// and shall be used to update the `Spar_Small_Tolerance` and `Spar_Large_Tolerance` respectively
Spar_Calibration_Small_Hole_ResultIndex = 7; //< Calibration hole start at where 0 for the first hole, 1 for second and so on
Spar_Calibration_Large_Hole_ResultIndex = 5; //< Calibration hole start at where 0 for the first hole, 1 for second and so on

Spar_Small_Tolerance= 0.21; // Print Tolerance for small spar holes ( 0.21 for 2mm rod based on calibration using PETG HF)
Spar_Large_Tolerance= 0.15; // Print Tolerance for large spar holes ( 0.15 for 4mm rod based on calibration using PETG HF)

Spar_Hole_Small_Diameter = Spar_Rod_Small_Diameter + Spar_Small_Tolerance;
Spar_Hole_Large_Diameter = Spar_Rod_Large_Diameter + Spar_Large_Tolerance;

/* [Design+Print Settings] */
// Enable vase mode printing optimizations
Design_For_VaseMode = false;
// Use hollow wing construction with additive spar structure (better for 3D printing)
// HOLLOW WING BENEFITS:
// - Spar structures print as solid positive features (no bridging)
// - Easier calibration by adjusting wall thickness
// - Stronger structure with integral spar elements
// - More material efficient (only print what's needed)
// DIAGNOSTIC: Set to false to test if hollow wing construction is causing render freeze
Use_Hollow_Wing_Construction = true;
// Wing shell thickness for hollow construction (mm)
Wing_Shell_Thickness = 1.2; // [0.4:0.1:3.0]
// Interface and gap width values
slice_ext_width = 0.6; // [0.1:0.1:2.0]
// Gap in outer skin (smaller is better, limited by slicer)
slice_gap_width = 0.05; // [0.01:0.01:0.5] 

/* [Main Wing Geometry Settings] */
// Based on AXIS PNG 1150 specifications
Main_Wing_span = 1150;               // Total main wing span in mm
Main_Wing_aspectratio = 7.72;        // Main wing aspect ratio
Main_Wing_area = 1713;               // Main wing area in cm²
Main_Wing_Average_Chord = Main_Wing_span / Main_Wing_aspectratio; // PNG 1150 has 149mm avg chord (1150/7.72)

// Power of the elliptic wing (2 = perfect ellipse)
Main_Wing_Eliptic_Pow = 2.5; // [1.0:0.1:8.0]

// NOTE: AXIS PNG 1150 Area Calculation - Theoretical Scale Factor Calculation
// The PNG 1150 has 1713 cm² area with 1150mm span and 7.72 aspect ratio
// The relationship between average chord and root chord depends on the elliptic power factor
// 4/π for elipse power 2.0 (true ellipse)
// TODO: A crude estimate for the scale factor based on elliptic power here!!
Main_Wing_Root_Chord_Scale_Factor = (4 - (Main_Wing_Eliptic_Pow - 2.0)/2)/PI;

// Main Wing dimensions
// Number of main wing sections (more = higher resolution)
Main_Wing_Sections = (Render_Mode_Fast_WingSlices || $preview) ? 20 : 100; // [10:5:150]
Main_Wing_mm = (Main_Wing_span / 2) * Build_Scale;         // Main wing length in mm (half span)
Main_Wing_Root_Chord_MM = Main_Wing_Average_Chord * Main_Wing_Root_Chord_Scale_Factor * Build_Scale;   // Root chord length in mm (calculated from average chord)
// Main wing tip chord length in mm (not relevant for elliptic wing)
Main_Wing_Tip_Chord_MM = 50 * Build_Scale; // [10:5:200]

// Wing shape settings
Main_Wing_Mode = 2; // [1:"Trapezoidal Wing", 2:"Elliptic Wing"]

// Percentage from leading edge for wing center line
MainWing_Center_Line_Perc = 90; // [0:100]

// Wing anhedral settings (degrees)
// Anhedral creates a downward angle of the wing tips for improved stability
// This defines the angle of the anhedral at the tip of the wing (degrees)
Wing_Anhedral_Degrees = 1.5; // [0:0.2:10]
// Where anhedral starts (percentage from root)
// This defines where the anhedral starts along the span - wing sections are rotated around x-axis and offset in y
Wing_Anhedral_Start_At_Percentage = 50; // [0:100]

// Main Wing Washout Settings
// Degrees of washout (0 = none) - washout adds twist for stability
Main_Wing_Washout_Deg = 1.0; // [0:0.1:10]
// Where washout starts (mm from root)
Main_Wing_Washout_Start = 60 * Build_Scale; // [0:10:500]
// Washout pivot point (percentage from LE)
Main_Wing_Washout_Pivot_Perc = 25; // [0:100]

/* [Airfoil Settings] */
// Where to change to center airfoil (100 = off)
center_airfoil_change_perc = 100; // [0:100]
// Where to change to tip airfoil (100 = off)
tip_airfoil_change_perc = 100; // [0:100]

// Create airfoil object from E818 airfoil data
 af_root = create_airfoil_object(airfoil_E818_slice(), Trailing_Edge_Thickness);

//Legacy support
af_vec_path_root = af_root.path;
af_vec_path_mid = af_root.path;
af_vec_path_tip = af_root.path;

// Airfoil bounding box
af_bbox = airfoil_E818_range();

// Number of slices for airfoil blending (0 = off)
slice_transisions = 0; // [0:1:20]

/*
 * WING CONFIGURATION OBJECTS
 * 
 * The wing configuration system uses hierarchical objects to organize parameters logically.
 * Key features:
 * 
 * - chord_profile: Groups all chord calculation parameters (root_chord_mm, tip_chord_mm, wing_mode, elliptic_pow)
 * - airfoil.paths: Pre-computed airfoil paths for optimal performance (full + preview resolution)
 * - WingSliceChordLength() accepts a chord_profile object for clean, type-safe interface
 * - Helper functions provide clean access to all configuration components
 * - wing_config_summary() creates debug-friendly output without bulky path data
 * - get_airfoil_path() provides clean access to airfoil paths when needed
 * 
 * This makes function calls cleaner, reduces parameter passing complexity, and eliminates
 * runtime path generation overhead by pre-computing all airfoil paths at configuration time.
 * All legacy parameter-based interfaces have been removed for cleaner code.
 */

// Main Wing Configuration Object - Hierarchical Structure
main_wing_config = object(
    // Basic geometry
    sections = Main_Wing_Sections,
    wing_mm = Main_Wing_mm,
    center_line_nx = MainWing_Center_Line_Perc/100,
    
    // Chord profile configuration - groups all chord-related parameters
    chord_profile = object(
        root_chord_mm = Main_Wing_Root_Chord_MM,
        tip_chord_mm = Main_Wing_Tip_Chord_MM,
        wing_mode = Main_Wing_Mode,
        elliptic_pow = Main_Wing_Eliptic_Pow
    ),
    
    // Anhedral configuration
    anhedral = object(
        degrees = Wing_Anhedral_Degrees,
        start_nz = Wing_Anhedral_Start_At_Percentage/100
    ),
    
    // Washout configuration
    washout = object(
        degrees = Main_Wing_Washout_Deg,
        start_nz = Main_Wing_Washout_Start / Main_Wing_mm,
        pivot_nx = Main_Wing_Washout_Pivot_Perc/100 // Pivot point as fraction from LE (0 to 1)
    ),
    
    // Airfoil transition configuration
    airfoil = object(
        tip_change_nz = tip_airfoil_change_perc/100,
        center_change_nz = center_airfoil_change_perc/100,
        // Pre-computed airfoil paths for performance
        paths = object(
            root = af_root,
            mid = af_root,
            tip = af_root,
        )
    ),
    
    // Print splitting configuration
    print = object(
        total_length = Main_Wing_mm,
        build_area = Printer_BuildArea,
        scale = Build_Scale,
        splits = ceil(Main_Wing_mm / (Printer_BuildArea.z * Build_Scale)),
        splits_length = Main_Wing_mm / ceil(Main_Wing_mm / (Printer_BuildArea.z * Build_Scale))
    )
);

/* [Rear Stabilizer Wing Geometry Settings] */
// Based on typical hydrofoil proportions (20-25% of main wing area)
Rear_Wing_Span = 340;                // Rear stabilizer span in mm (typical 25-30% of main span)
Rear_Wing_Aspect = 4.0;         // Rear stabilizer aspect ratio (typically lower than main wing)
Rear_Wing_Area = 428;                // Rear stabilizer area in cm² (25% of main wing area)
Rear_Wing_Chord = Rear_Wing_Span / Rear_Wing_Aspect; // 75mm avg chord (300/4.0)

// Rear Wing dimensions
// Number of rear wing sections (more = higher resolution)
Rear_Wing_sections = (Render_Mode_Fast_WingSlices || $preview) ? 15 : 75; // [8:3:100]
Rear_Wing_mm = (Rear_Wing_Span / 2) * Build_Scale;         // Rear wing length in mm (half span)
Rear_Wing_root_chord_mm = Rear_Wing_Chord * Build_Scale;   // Rear root chord length in mm
// Rear wing tip chord length in mm (not relevant for elliptic wing)
Rear_Wing_tip_chord_mm = 25 * Build_Scale; // [5:2:100]

// Rear Wing shape settings
Rear_Wing_mode = 2; // [1:"Trapezoidal Wing", 2:"Elliptic Wing"]

// Power of the elliptic rear wing (2 = perfect ellipse)
Rear_Wing_eliptic_pow = 2.0; // [1.0:0.1:3.0]
// Percentage from leading edge for rear wing center line
Rear_MainWing_Center_Line_Perc = 95; // [0:100]

// Rear wing anhedral settings (degrees)
// Rear wing anhedral is typically less than main wing
Rear_Wing_Anhedral_Degrees = 5.0; // [0:0.2:5]
// Where rear wing anhedral starts (percentage from root)
Rear_Wing_Anhedral_Start_At_Percentage = 60; // [0:100]

// Rear Wing Washout Settings
// Rear wing degrees of washout (0 = none) - washout adds twist for stability
Rear_Wing_Washout_Deg = 0.0; // [0:0.1:5]
// Where rear wing washout starts (mm from root)
Rear_Wing_Washout_Start = 30 * Build_Scale; // [0:5:200]
// Rear wing washout pivot point (percentage from LE)
Rear_Wing_Washout_Pivot_Perc = 25; // [0:100]

// Rear Wing Configuration Object - Hierarchical Structure
rear_wing_config = object(
    // Basic geometry
    sections = Rear_Wing_sections,
    wing_mm = Rear_Wing_mm,
    center_line_nx = Rear_MainWing_Center_Line_Perc/100,
    
    // Chord profile configuration - groups all chord-related parameters
    chord_profile = object(
        root_chord_mm = Rear_Wing_root_chord_mm,
        tip_chord_mm = Rear_Wing_tip_chord_mm,
        wing_mode = Rear_Wing_mode,
        elliptic_pow = Rear_Wing_eliptic_pow
    ),
    
    // Anhedral configuration
    anhedral = object(
        degrees = Rear_Wing_Anhedral_Degrees,
        start_nz = Rear_Wing_Anhedral_Start_At_Percentage/100
    ),
    
    // Washout configuration
    washout = object(
        degrees = Rear_Wing_Washout_Deg,
        start_nz = Rear_Wing_Washout_Start / Rear_Wing_mm,
        pivot_nx = Rear_Wing_Washout_Pivot_Perc/100
    ),
    
    // Airfoil transition configuration
    airfoil = object(
        tip_change_nz = tip_airfoil_change_perc/100,
        center_change_nz = center_airfoil_change_perc/100,
        // Pre-computed airfoil paths for performance
        paths = object(
            root = af_root,
            mid = af_root,
            tip = af_root,
        )
    ),
    
    // Print splitting configuration
    print = object(
        total_length = Rear_Wing_mm,
        build_area = Printer_BuildArea,
        scale = Build_Scale,
        splits = ceil(Rear_Wing_mm / (Printer_BuildArea.z * Build_Scale)),
        splits_length = Rear_Wing_mm / ceil(Rear_Wing_mm / (Printer_BuildArea.z * Build_Scale))
    )
);

/* [ Wing Position Settings] */

// Rear wing positioning on fuselage
Rear_Wing_position_from_main = 650; // Distance from main wing to rear wing in mm (typical 3-4x main chord)
Rear_Wing_vertical_offset = 0;       // Vertical offset of rear wing from main wing centerline in mm
Rear_Wing_angle_offset = 0;          // Angle offset of rear wing relative to main wing in degrees (positive = nose up)


/* [Fuselage Geometry Settings] */
// Based on AXIS PNG 1150 fuselage specifications
fuselage_type = 1;              // [1:"Standard 765mm", 2:"Short 685mm", 3:"Ultrashort 605mm", 4:"Crazyshort 525mm"]
fuselage_rod_od= [19, 19]; // Square rod dimensions for length of fuselage construction
fuselage_rod_wall= [3.3, 3.3]; // Square rod wall thickness
fuselage_rod_id= fuselage_rod_od-fuselage_rod_wall; // Square rod inner dimensions

fuselage_width = fuselage_rod_od.x;            // Fuselage width (horizontal dimension) in mm
fuselage_height = fuselage_rod_od.y;           // Fuselage height (vertical dimension) in mm
fuselage_taper_ratio = 1.0;     // Taper ratio from root to tip (NOTE: For rod construction we cannot taper the fuselage, so this is set to 1.0)


// Fuselage connection specifications
mast_connection_diameter = 19;   // Mast connection diameter in mm (AXIS 19mm standard)
mast_connection_length = 100;    // Mast connection length in mm
spar_through_fuselage = true;    // Wing spars pass through fuselage (no separate bolts)
stabilizer_connection_spacing = 50; // Distance between stabilizer mounting bolts in mm

/* [Internal Grid Structure Settings] */
// Add inner grid for 3D printing (!Print_For_VaseMode)
add_inner_grid = true;
// 1=diamond grid, 2=spar and cross spars (legacy), 3=configured spar grid (uses spar config)
grid_mode = 3;
// Add holes to ribs to decrease weight
create_rib_voids = false;

// Grid Thickness Control
// Grid thickness multiplier for structural integrity (larger = thicker grid)
Grid_Thickness_Multiplier = 0.5; // [0.2:0.1:2.0]
// Override grid thickness (0 = use calculated thickness based on spar diameters)
Grid_Override_Thickness = 0; // [0:0.5:5.0]

// Grid Mode 1 Settings (Diamond Grid)
// Changes the size of inner grid blocks
grid_size_factor = 2; // [1:1:10]

// Grid Mode 2 Settings (Legacy Spar and Cross Spars) - Uses linear spacing
// Number of spars
spar_num = 3; // [1:1:10]
// Offset spars from LE/TE
spar_offset = 15; // [0:5:50]
// Number of ribs
rib_num = 6; // [1:1:20]
// Rib offset
rib_offset = 1; // [0:1:10]

// Grid Mode 3 Settings (Configured Spar Grid) - Uses spar configuration positions
// Grid settings are defined in main_wing_spar_config.grid object
// Individual spar positions are defined in main_wing_spar_config.spars array

// CARBON SPAR SYSTEM
// Helper functions to access chord profile components cleanly
function get_wing_mode(wing_config) = wing_config.chord_profile.wing_mode;
function get_root_chord_mm(wing_config) = wing_config.chord_profile.root_chord_mm;
function get_tip_chord_mm(wing_config) = wing_config.chord_profile.tip_chord_mm;
function get_elliptic_pow(wing_config) = wing_config.chord_profile.elliptic_pow;


// Function to calculate the ideal spar offset based on airfoil geometry
// nx: Normalized X from leading edge (0-1)  
// wing_config: Wing configuration object containing airfoil data
// anchor: BOSL2 anchor constant (TOP, BOTTOM, CENTER) for airfoil surface selection
// Returns the y-offset at that chord position for optimal structural positioning
function calculate_spar_offset_at_chord_position(nx, wing_config, anchor=CENTER) = 
    let(
        // Get the appropriate airfoil line data using anchor
        af_vec = get_airfoil_surface(anchor),
      //  _ = echo("af_vec", af_vec, "nx", nx, "anchor", anchor),
        // Simple linear search for the closest point (efficient for small datasets)
        closest_index = 
            nx <= af_vec[0].x ? 0 :
            nx >= af_vec[len(af_vec)-1].x ? len(af_vec)-1 :
            // Find first point where x >= nx
            [for (i = [0 : len(af_vec) - 1]) 
                if (af_vec[i].x >= nx) i][0],
        
        // Get the y-coordinate at that position
        y_offset = af_vec[closest_index].y * get_root_chord_mm(wing_config) // Scale to mm from percentage
    ) y_offset;

// Helper function to create a wing config summary for debug printing (excludes bulky path data)
function wing_config_summary(wing_config) = object(
    sections = wing_config.sections,
    wing_mm = wing_config.wing_mm,
    center_line_nx = wing_config.center_line_nx,
    chord_profile = wing_config.chord_profile,
    anhedral = wing_config.anhedral,
    washout = wing_config.washout,
    airfoil = object(
        tip_change_nz = wing_config.airfoil.tip_change_nz,
        center_change_nz = wing_config.airfoil.center_change_nz,
        paths = "[AIRFOIL PATHS OMITTED FOR READABILITY]"
    ),
    print = wing_config.print
);

// Function to create a new spar configuration using BOSL2 anchor constants
// percx: Percentage from leading edge
// diam: Size of the spar hole  
// length: Length of the spar in mm
// offset: Manual offset override
// anchor: BOSL2 anchor constant (TOP, BOTTOM, CENTER) for airfoil positioning
function new_spar(percx, diam, length, offset, anchor=undef, fixedx=undef) = object(
    x = ((fixedx == undef) ? percx/100 * get_root_chord_mm(main_wing_config): fixedx) * Build_Scale, // X position based on chord percentage or fixed x
    diameter = undef, //TODO: We should have the diameter here, but it is not used in the spar hole creator
    anchor = anchor, // Anchor for airfoil surface selection
    hole_diameter = diam * Build_Scale,
    length = length * Build_Scale,
    offset = ((anchor != undef ? calculate_spar_offset_at_chord_position(percx/100, main_wing_config, anchor) : 0) + offset) * Build_Scale
);

/**
 * Function to create a new spar configuration object for unified spar/grid system
 * This creates more legible spar configurations that can be used for both holes and grid generation
 * 
 * @param type - Spar type: "structural" (full-span through fuselage) or "secondary" (split at centerline)
 * @param diameter - Rod diameter in mm (before tolerance)
 * @param length - Spar length in mm
 * @param anchor - BOSL2 anchor constant (TOP, BOTTOM, CENTER) for airfoil positioning
 * @param offset - Manual y-offset adjustment in mm
 * @param name - Optional descriptive name for debugging
 * @param fixedx - Fixed position in mm from leading edge (mutually exclusive with percentx)
 * @param percentx - Percentage position from leading edge (mutually exclusive with fixedx)
 */
function new_spar_config(type, diameter, length, anchor=CENTER, offset=0, name=undef, fixedx=undef, percentx=undef) = 
    let(
        // Validate that exactly one position parameter is provided
        _ = assert(
            (fixedx != undef && percentx == undef) || (fixedx == undef && percentx != undef),
            "Must specify exactly one of fixedx or percentx"
        )
    )
    object(
        // Metadata
        type = type, // "structural" or "secondary"
        name = name,
        
        // Position
        x_percent = percentx,
        x_mm = fixedx,
        
        // Physical properties
        rod_diameter = diameter,
        hole_diameter = (diameter == Spar_Rod_Small_Diameter) ? Spar_Hole_Small_Diameter : 
                       (diameter == Spar_Rod_Large_Diameter) ? Spar_Hole_Large_Diameter : 
                       diameter + 0.15, // Default tolerance if not standard size
        length = length,
        
        // Positioning
        anchor = anchor,
        offset = offset
    );

/**
 * Function to create a paired spar configuration (top + bottom holes with shared grid spar)
 * This creates a composite spar object that generates both top and bottom holes
 * plus a structural grid element at the same chord position
 * 
 * @param name - Descriptive name for the paired spar system
 * @param top_diameter - Rod diameter for top hole in mm
 * @param top_length - Length for top spar in mm  
 * @param top_offset - Y-offset adjustment for top hole in mm
 * @param top_anchor - BOSL2 anchor constant for top hole positioning (TOP, BOTTOM, CENTER)
 * @param bottom_diameter - Rod diameter for bottom hole in mm
 * @param bottom_length - Length for bottom spar in mm
 * @param bottom_offset - Y-offset adjustment for bottom hole in mm
 * @param bottom_anchor - BOSL2 anchor constant for bottom hole positioning (TOP, BOTTOM, CENTER)
 * @param fixedx - Fixed position in mm from leading edge (mutually exclusive with percentx)
 * @param percentx - Percentage position from leading edge (mutually exclusive with fixedx)
 */
function new_paired_spar_config(name, top_diameter, top_length, top_offset, top_anchor, bottom_diameter, bottom_length, bottom_offset, bottom_anchor, fixedx=undef, percentx=undef) = 
    let(
        // Validate that exactly one position parameter is provided
        _ = assert(
            (fixedx != undef && percentx == undef) || (fixedx == undef && percentx != undef),
            "Must specify exactly one of fixedx or percentx"
        ),
        
        // Create top and bottom spar configs using new_spar_config for consistency
        top_config = new_spar_config("secondary", top_diameter, top_length, top_anchor, top_offset, 
                                    str(name, " Top"), fixedx=fixedx, percentx=percentx),
        bottom_config = new_spar_config("secondary", bottom_diameter, bottom_length, bottom_anchor, bottom_offset, 
                                       str(name, " Bottom"), fixedx=fixedx, percentx=percentx)
    )
    object(
        // Metadata
        type = "paired", // New type for paired top/bottom spars
        name = name,
        
        // Position (shared by both top and bottom)
        x_percent = percentx,
        x_mm = fixedx,
        
        // Top and bottom spar configurations using new_spar_config
        top_config = top_config,
        bottom_config = bottom_config
    );

/**
 * Helper function to extract x-position in mm from spar config for a given wing
 * Works with both single and paired spar configurations
 */
function get_spar_x_mm(spar_config, wing_config) = 
    (spar_config.x_mm != undef) ? spar_config.x_mm * Build_Scale :
    (spar_config.x_percent / 100) * get_root_chord_mm(wing_config) * Build_Scale;

/**
 * Helper function to expand paired spar config into individual spar hole configs
 * Returns an array of individual spar configs (1 for single, 2 for paired)
 */
function expand_spar_config(spar_config) = 
    (spar_config.type == "paired") ? [
        // Return the pre-created top and bottom spar configs
        spar_config.top_config,
        spar_config.bottom_config
    ] : [spar_config]; // Single spar configs return as-is

/**
 * Helper function to get all individual spar configs (expands paired spars)
 */
function get_all_individual_spars(spar_config) = 
    flatten([for (spar = spar_config.spars) expand_spar_config(spar)]);

/**
 * Helper function to convert spar config to legacy spar hole format
 */
function spar_config_to_hole(spar_config, wing_config) = object(
    x = get_spar_x_mm(spar_config, wing_config),
    diameter = undef, // Legacy compatibility
    anchor = spar_config.anchor,
    hole_diameter = spar_config.hole_diameter * Build_Scale,
    length = spar_config.length * Build_Scale,
    offset = ((spar_config.anchor != undef) ? 
        calculate_spar_offset_at_chord_position(
            (spar_config.x_percent != undef ? spar_config.x_percent/100 : spar_config.x_mm/get_root_chord_mm(wing_config)), 
            wing_config, 
            spar_config.anchor
        ) : 0) + (spar_config.offset * Build_Scale)
);

/**
 * MAIN WING SPAR CONFIGURATION
 * 
 * Unified spar configuration system that defines both spar holes and grid structure.
 * Uses new_spar_config() for legible, consistent configuration.
 * 
 * Spar Types:
 * - "structural": Full-span spars that go through the fuselage as one piece
 * - "secondary": Wing-only spars that are split at the centerline
 */
main_wing_spar_config = object(
    // Individual spar definitions
    spars = [
        // STRUCTURAL SPARS - Full-span through fuselage (fixed positions for fuselage compatibility)
        new_spar_config("structural", Spar_Rod_Large_Diameter, 400, undef, 0.5, "Front Main Spar", fixedx=45),
        new_spar_config("structural", Spar_Rod_Large_Diameter, 400, undef, 1.5, "Center Main Spar", fixedx=80), 
        new_spar_config("structural", Spar_Rod_Large_Diameter, 400, undef, 2.5, "Rear Main Spar", fixedx=115),
        
        // SECONDARY SPARS - Wing-only, single holes
        new_spar_config("secondary", Spar_Rod_Small_Diameter, 300, CENTER, 0.5, "Forward Secondary", percentx=10),
        new_spar_config("secondary", Spar_Rod_Small_Diameter, 400, BOTTOM, 2, "Trailing Edge", percentx=75),
        
        // PAIRED SPARS - Top and bottom holes with structural grid capability
        new_paired_spar_config("Leading Edge Dual", 
            Spar_Rod_Small_Diameter, 250, -3.5, TOP,       // top: diameter, length, offset, anchor
            Spar_Rod_Small_Diameter, 250, 3.25, BOTTOM,    // bottom: diameter, length, offset, anchor
            percentx=15),
        
        new_paired_spar_config("Mid Forward Dual",
            Spar_Rod_Small_Diameter, 300, -3.5, TOP,       // top: diameter, length, offset, anchor
            Spar_Rod_Small_Diameter, 450, 3, BOTTOM,       // bottom: diameter, length, offset, anchor
            percentx=35),
            
        new_paired_spar_config("Mid Rear Dual", 
            Spar_Rod_Small_Diameter, 300, -3, TOP,         // top: diameter, length, offset, anchor
            Spar_Rod_Small_Diameter, 450, 3, BOTTOM,       // bottom: diameter, length, offset, anchor
            percentx=55)
    ],
    
    // Grid generation settings
    grid = object(
        enabled = true,
        mode = "spar_based", // Use spar positions instead of linear spacing
        // Grid thickness - use override if specified, otherwise calculate from spar diameters
        large_rod_thickness = (Grid_Override_Thickness > 0) ? Grid_Override_Thickness : 
                             (Spar_Rod_Large_Diameter * Grid_Thickness_Multiplier), // Default: 2mm for 4mm rod with 0.5 multiplier
        small_rod_thickness = (Grid_Override_Thickness > 0) ? Grid_Override_Thickness : 
                             (Spar_Rod_Small_Diameter * Grid_Thickness_Multiplier), // Default: 1mm for 2mm rod with 0.5 multiplier
        rib_thickness = (Grid_Override_Thickness > 0) ? Grid_Override_Thickness : 
                       (Spar_Rod_Small_Diameter * Grid_Thickness_Multiplier), // Use small rod thickness for ribs
        rib_count = 6,
        rib_offset = 1
    )
);

// Helper functions for spar configuration
function get_structural_spars(spar_config) = [for (spar = spar_config.spars) if (spar.type == "structural") spar];
function get_secondary_spars(spar_config) = [for (spar = spar_config.spars) if (spar.type == "secondary") spar];
function get_paired_spars(spar_config) = [for (spar = spar_config.spars) if (spar.type == "paired") spar];
// All spars now contribute to grid structure - no filtering needed
function get_grid_spars(spar_config) = spar_config.spars;
function get_all_spar_x_positions(spar_config, wing_config) = [for (spar = get_all_individual_spars(spar_config)) get_spar_x_mm(spar, wing_config)];

// Generate legacy spar_holes array from spar configuration for backward compatibility
function generate_spar_holes(spar_config, wing_config) = [
    for (spar = get_all_individual_spars(spar_config)) spar_config_to_hole(spar, wing_config)
];

// Spar hole configurations - generated from unified spar configuration
// Uses calculated offsets based on airfoil geometry for optimal structural positioning
spar_holes = generate_spar_holes(main_wing_spar_config, main_wing_config);

spar_hole_void_clearance = 0.0;  // Clearance for spar to grid interface (at least double extrusion width)

// Required position assertions for consistency of fuselage fit (structural spars)
structural_spars = get_structural_spars(main_wing_spar_config);
spar_0_x = get_spar_x_mm(structural_spars[0], main_wing_config);
spar_1_x = get_spar_x_mm(structural_spars[1], main_wing_config);
spar_2_x = get_spar_x_mm(structural_spars[2], main_wing_config);

echo(str("DEBUG: Structural spar positions - 0:", spar_0_x, "mm, 1:", spar_1_x, "mm, 2:", spar_2_x, "mm"));
echo(str("DEBUG: Build_Scale = ", Build_Scale));

assert( spar_0_x == 45, str("Structural spar 0 should be at x=45mm, got ", spar_0_x, "mm") );
assert( spar_1_x == 80, str("Structural spar 1 should be at x=80mm, got ", spar_1_x, "mm") );
assert( spar_2_x == 115, str("Structural spar 2 should be at x=115mm, got ", spar_2_x, "mm") );


// LIBRARY INCLUDES

include <lib/Helpers.scad>
include <lib/Fuselage.scad>
include <lib/Grid-Structure.scad>
include <lib/Grid-Void-Creator.scad>
include <lib/Rib-Void-Creator.scad>
include <lib/Spar-Hole.scad>
include <lib/Wing-Creator.scad>


/**
 * Rear wing creation module using object configuration
 * Uses wing configuration object for cleaner parameter passing
 */
module CreateRearWing() {
    CreateWing(rear_wing_config) {
        // Rear wing typically has simpler internal structure
        // Could add rear wing specific spar holes here if needed
        // wing_spar_holes(rear_spar_holes); // if defined
    };
}

// MAIN WING MODULE  
module main_wing() {
   // translate([get_root_chord_mm(wing_config) * wing_config.center_line_nx, 0, 0])
    
    if (Use_Hollow_Wing_Construction) {
        // New hollow wing construction with additive spar structure
        CreateHollowWing(main_wing_config, Wing_Shell_Thickness, add_connections=false) {
            // Internal structures - automatically get anhedral compensation rotation
            down(fuselage_rod_od.x/2) {
                if (add_inner_grid ) {
                    // DIAGNOSTIC: Temporarily disable complex spar structures to test render performance
                    // Comment this out to test if hollow wing shell alone renders fine
                    if (true) { // Set to true to enable full spar structures
                        wing_intersect() {
                            hollow_wing_spars(main_wing_spar_config, main_wing_config);
                        }
                    } else {
                        // Minimal test: just add a simple cube to verify hollow wing works
                        wing_intersect() {
                            echo("DIAGNOSTIC: Using minimal internal structure for testing");
                            translate([50, 0, 50]) cube([10, 5, 100]);
                        }
                    }
                }
            }
        }
    } else {
        // Traditional solid wing construction (legacy)
        CreateWing(main_wing_config, add_connections=false) {
            // Internal structures - automatically get anhedral compensation rotation
            down(fuselage_rod_od.x/2)
            {
                if (add_inner_grid && false) {
                    wing_remove() {
                        // Add grid structure
                        if (grid_mode == 1) {
                           StructureGrid(main_wing_config.wing_mm, get_root_chord_mm(main_wing_config), grid_size_factor);
                        } else if (grid_mode == 2) {
                           StructureSparGrid(main_wing_config.wing_mm, get_root_chord_mm(main_wing_config), grid_size_factor, spar_num, spar_offset,
                                            rib_num, rib_offset);
                        } else if (grid_mode == 3) {
                           StructureSparGridConfigured(main_wing_config, main_wing_spar_config);
                        }
                        
                        //TODO: Freezes atm
                        if(false/*temp*/){
                                // Remove voids from grid
                                union() {
                                    if (grid_mode == 1) {
                                        if (create_rib_voids) {
                                            CreateRibVoids();
                                        }
                                    } else if (grid_mode == 2) {
                                        if (create_rib_voids) {
                                            CreateRibVoids2();
                                        }
                                    } else if (grid_mode == 3) {
                                        if (create_rib_voids) {
                                            CreateRibVoids2(); // Use same void system as mode 2
                                        }
                                    }
                                    
                                    // Remove spar void spaces from grid
                                    for (spar = spar_holes) {
                                        CreateSparVoid(spar);
                                    }
                                    
                                    // Remove grid void
                                    CreateGridVoid();
                                }
                        }
                    }
                }
                
                // Spar holes - cleaner syntax using helper module
               wing_spar_holes(spar_holes);
            }
        }
    }
}

// REAR WING MODULE
module Rear_Wing() {
    // Position rear wing relative to main wing
   translate([Rear_Wing_position_from_main,0, 0]) {
        translate([0, Rear_Wing_vertical_offset, 0]) {
            rotate([Rear_Wing_angle_offset, 0, 0]) {
                 xrot(180) CreateWing(rear_wing_config);
            }
        }
    }
}

// VALIDATION AND MAIN EXECUTION
// Input validation
if (Main_Wing_Sections * 0.2 < slice_transisions) {
    echo("ERROR: You should lower the amount of slice_transisions.");
} else if (center_airfoil_change_perc < 0 || center_airfoil_change_perc > 100) {
    echo("ERROR: center_airfoil_change_perc has to be in a range of 0-100.");
}

// Calculate actual wing area from the model geometry
Main_Wing_Area_Actual = calculate_actual_wing_area(main_wing_config);
Main_Wing_Area_ErrorPercentage = round((Main_Wing_Area_Actual/100 - Main_Wing_area)/Main_Wing_area * 100);

Main_Wing_Area_DoAnalysis = (abs(Main_Wing_Area_ErrorPercentage) > 2.5);

// Version check - require OpenSCAD 2025.7+ for object() function support
echo(str("OpenSCAD version: ", OpenScad_SemVer[0], ".", OpenScad_SemVer[1], ".", OpenScad_SemVer[2] ));

OpenScad_SemVer = version();
OpenScad_SemVer_Required = [2025, 7]; // Minimum required version for object() function support
// Check if OpenSCAD version is compatible
OpenScad_VersionOk = (OpenScad_SemVer[0] > OpenScad_SemVer_Required[0]) || (OpenScad_SemVer[0] == OpenScad_SemVer_Required[0] && OpenScad_SemVer[1] >= OpenScad_SemVer_Required[1]);

if (!OpenScad_VersionOk) {
    assert(false, "Incompatible OpenSCAD version - requires 2025.7+ - Please upgrade to OpenSCAD nightly build");
}

// Debug: Show wing configuration objects (paths omitted for readability)
echo("=== WING CONFIGURATION OBJECTS ===");
echo("Main wing config:", wing_config_summary(main_wing_config));
echo("Rear wing config:", wing_config_summary(rear_wing_config));
echo("===================================");

// Debug: Show spar configuration details
echo("=== SPAR CONFIGURATION DETAILS ===");
echo("Structural spars:", len(get_structural_spars(main_wing_spar_config)));
echo("Secondary spars:", len(get_secondary_spars(main_wing_spar_config)));
echo("Paired spars:", len(get_paired_spars(main_wing_spar_config)));
echo("All spars contribute to grid structure");
echo("Total individual holes:", len(get_all_individual_spars(main_wing_spar_config)));
echo("Total spar configs:", len(main_wing_spar_config.spars));
for (i = [0:len(main_wing_spar_config.spars)-1]) {
    spar = main_wing_spar_config.spars[i];
    x_pos = get_spar_x_mm(spar, main_wing_config);
    if (spar.type == "paired") {
        echo(str("Spar ", i, " (", spar.type, "): ", 
            spar.name != undef ? spar.name : "unnamed",
            " @ ", x_pos/Build_Scale, "mm",
            ", top: ", spar.top_config.rod_diameter, "mm rod",
            ", bottom: ", spar.bottom_config.rod_diameter, "mm rod"));
    } else {
        echo(str("Spar ", i, " (", spar.type, "): ", 
            spar.name != undef ? spar.name : "unnamed",
            " @ ", x_pos/Build_Scale, "mm, ", 
            spar.rod_diameter, "mm rod, ",
            spar.anchor, " anchor"));
    }
}
echo("===================================");


// Display hydrofoil specifications
echo("========================================");
echo("     HYDROFOIL BOARD SPECIFICATIONS     ");
echo("========================================");
echo(str("Main Wing Span: ", Main_Wing_span, " mm"));
echo(str("Main Wing Area: ", Main_Wing_area, " cm² (actual: ", Main_Wing_Area_Actual/100, " cm², diff: ", (Main_Wing_Area_Actual/100 - Main_Wing_area), " cm² [", 
    Main_Wing_Area_ErrorPercentage, "%])"));
echo(str("Main Wing Aspect Ratio: ", Main_Wing_aspectratio));
echo(str("Main Wing Average Chord: ", Main_Wing_Average_Chord, " mm"));
echo(str("Main Wing Root Chord: ", Main_Wing_Root_Chord_MM, " mm"));

if ( Main_Wing_Area_DoAnalysis )
{
    // Diagnostic calculations for AXIS PNG 1150
    theoretical_ellipse_area_with_root = (PI/2) * Main_Wing_mm * Main_Wing_Root_Chord_MM; // Full wing (both halves) using actual root chord
    theoretical_ellipse_area_with_avg = Main_Wing_span * (Main_Wing_Average_Chord * Build_Scale); // Full wing (both halves) using average chord (planform area)
    echo(str("=== ELLIPTIC SCALE FACTOR ANALYSIS ==="));
    echo(str("Elliptic power factor: ", Main_Wing_Eliptic_Pow));
    echo(str("Calculated scale factor: ", Main_Wing_Root_Chord_Scale_Factor));
    echo(str("Applied root chord: ", Main_Wing_Root_Chord_MM, " mm (", Main_Wing_Average_Chord, " × ", Main_Wing_Root_Chord_Scale_Factor, ")"));
    echo(str("=== AREA DIAGNOSTIC CALCULATIONS ==="));
    echo(str("Theoretical ellipse area (π*b*c_root): ", theoretical_ellipse_area_with_root/100, " cm²"));
    echo(str("Theoretical planform area (b*c_avg): ", theoretical_ellipse_area_with_avg/100, " cm²"));
    echo(str("PNG 1150 should have area: ", PI/4 * Main_Wing_span * Main_Wing_Average_Chord / 100, " cm²"));
    echo(str("Current elliptic power: ", Main_Wing_Eliptic_Pow));
    echo(str("=== EMPIRICAL SCALE FACTOR ==="));
    echo(str("Applied root chord: ", Main_Wing_Root_Chord_MM, " mm (", Main_Wing_Average_Chord, " × ", Main_Wing_Root_Chord_Scale_Factor, ")"));
    echo(str("==========================="));
}
echo("----------------------------------------");
echo(str("Rear Wing Span: ", Rear_Wing_Span, " mm"));
echo(str("Rear Wing Area: ", Rear_Wing_Area, " cm²"));
echo(str("Rear Wing Aspect Ratio: ", Rear_Wing_Aspect));
echo(str("Rear Wing Average Chord: ", Rear_Wing_Chord, " mm"));
echo(str("Rear Wing Position: ", Rear_Wing_position_from_main, " mm from main"));
echo("----------------------------------------");
echo(str("Fuselage Length: ", get_fuselage_length(), " mm"));
echo(str("Fuselage Type: ", 
    fuselage_type == 1 ? "Standard (765mm)" :
    fuselage_type == 2 ? "Short (685mm)" :
    fuselage_type == 3 ? "Ultrashort (605mm)" :
    "Crazyshort (525mm)"
));
echo(str("Fuselage Dimensions: ", fuselage_width, " × ", fuselage_height, " mm"));
echo("----------------------------------------");
echo(str("Number of Spars: ", len(main_wing_spar_config.spars), " (", len(get_structural_spars(main_wing_spar_config)), " structural + ", len(get_secondary_spars(main_wing_spar_config)), " secondary)"));
echo(str("Spar Through Design: ", spar_through_fuselage ? "Yes" : "No"));
echo("----------------------------------------");
echo(str("Build Scale: ", Build_Scale, "x"));
echo(str("Scaled Main Wing Half-Span: ", Main_Wing_mm, " mm"));
echo(str("Scaled Rear Wing Half-Span: ", Rear_Wing_mm, " mm"));
echo("========================================");

/*else if (add_inner_grid == false && spar_hole == true) {
    echo("ERROR: add_inner_grid needs to be true for spar_hole to be true");
}*/

if (false /*dev*/ && $preview )
{
    // Development mode - show hollow vs solid wing comparison
    if (Use_Hollow_Wing_Construction) {
     back_half(s=main_wing_config.wing_mm*2)       
            main_wing();
            
            // Show solid wing in transparent red for comparison
           # color([1,0,0,0.3]) translate([0, -50, 0]) {
                CreateWing(main_wing_config, add_connections=false) {
                    down(fuselage_rod_od.x/2) {
                        if (add_inner_grid) {
                            wing_remove() StructureSparGridConfigured(main_wing_config, main_wing_spar_config);
                        }
                        wing_spar_holes(spar_holes);
                    }
                }
        }
    } else {
        front_half() main_wing();
    }
}
else
if ( Main_Wing_Area_DoAnalysis )
{
    visualize_actual_wing_area(main_wing_config);
    fwd(15) visualize_wing_area_calculation(main_wing_config);
}
else // Main execution
if(Build_CalibrationParts) {
    thickness = (Spar_Calibration_Large_Hole_ResultIndex != undef) ? Printer_BuildArea.z-30 : 2.5;
    crop_x = (Spar_Calibration_Large_Hole_ResultIndex != undef) ? Main_Wing_Average_Chord * 0.3 : Printer_BuildArea.x;
    count = 10; // Number of small/large spar holes to create +1 for 0 tolerance)
    max_tolerance = 0.30;

    Spar_Calibration_Large_Tolerance = Spar_Calibration_Large_Hole_ResultIndex * (max_tolerance/count);
    Spar_Calibration_Small_Tolerance = Spar_Calibration_Small_Hole_ResultIndex * (max_tolerance/count);
    // Calculate calibration tolerance based on result
    if (Spar_Calibration_Large_Hole_ResultIndex != undef) {
        echo(str("Calibration Spar-Hole tolerance: ",
         " Spar_Small_Tolerance= ", Spar_Calibration_Small_Tolerance,
         " Spar_Large_Tolerance= ", Spar_Calibration_Large_Tolerance));
    }

    // Print the lower 1.5mm of each wing part
    union()
    {
        intersection() {
            difference() 
            {
                CreateWing(main_wing_config);
                
                 if (Spar_Calibration_Large_Hole_ResultIndex != undef) {
                    
                    for (iSpar = [-1:1]) {
                        tolerance = (iSpar+Spar_Calibration_Large_Hole_ResultIndex) * (max_tolerance/count);

                        smallSpar=new_spar(15 + ((iSpar+1) * 4) , Spar_Rod_Small_Diameter + tolerance, thickness+2, Spar_Rod_Small_Diameter/2 + 1.5+max_tolerance, BOTTOM);
                        CreateSparHole(smallSpar);

                        largeSpar=new_spar(15 + ((iSpar+1) * 4) , Spar_Rod_Large_Diameter + tolerance, thickness+2, -(Spar_Rod_Large_Diameter/2 +1.5+max_tolerance), TOP);
                        CreateSparHole(largeSpar);
                    }
                 }
                 else
                 {
                    //Small calibrations
                    for (iSpar = [0:count]) {
                        tolerance = iSpar * (max_tolerance/count);

                        smallSpar=new_spar(15 + (iSpar * 4) , Spar_Rod_Small_Diameter + tolerance, thickness+2, Spar_Rod_Small_Diameter/2 + 1.5+max_tolerance, BOTTOM);
                        CreateSparHole(smallSpar);

                        largeSpar=new_spar(15 + (iSpar * 4) , Spar_Rod_Large_Diameter + tolerance, thickness+2, -(Spar_Rod_Large_Diameter/2 +1.5+max_tolerance), TOP);
                        CreateSparHole(largeSpar);
                    }
                }
            };
            cube([crop_x, Printer_BuildArea.y, thickness], anchor=BOTTOM+LEFT);
        }
        
        dim_label =(Spar_Calibration_Large_Hole_ResultIndex != undef) ? str("-", Spar_Calibration_Large_Hole_ResultIndex, "+") : str("0-",max_tolerance);

        translate([8, 0.5, thickness])
            linear_extrude(height = 0.5)
                 text(dim_label, size = 4, valign = "center", halign = "left");
                 
    }
}
else
if(Build_TestParts) {
    
    // Main Wing Slice(s) - using wing configuration
    split_wing_into_parts(main_wing_config.print, 5) main_wing();

    // Rear wing slice(s) - using wing configuration
    fwd(20) split_wing_into_parts(rear_wing_config.print, 5) CreateRearWing();

    //Longitudinal slices - using wing configuration
    fwd(40) yrot(90) left(Main_Wing_Average_Chord*Build_Scale/2+1) split_wing_into_parts(main_wing_config.print) intersection() {
        main_wing();
        right(Main_Wing_Average_Chord*Build_Scale/2) cube([2,100, main_wing_config.wing_mm*Build_Scale], anchor=BOTTOM+CENTER);
    }

    Main_Wing_Slot_Height=3.2;
    Main_Wing_Slot_Width=6;
    Main_Wing_Slot_Taper=1;
    Main_Wing_Slot_Slope=4;
    Main_Wing_Slot_Radius=0.35;

    Main_Wing_Slot_Length=Main_Wing_Slot_Width*1.5;
    Main_Wing_Slot_EntryLength=Main_Wing_Slot_Length+0.8; // Length of the entry slot for dovetail

    xdistribute(spacing=Main_Wing_Slot_Width+6){
        cuboid([Main_Wing_Slot_Width+4,Main_Wing_Slot_Length+Main_Wing_Slot_EntryLength+4,4], anchor=BOT)
            attach(TOP,BOT,align=BACK,inset=2)
            dovetail("male", slide=Main_Wing_Slot_Length, width=Main_Wing_Slot_Width, height=Main_Wing_Slot_Height, slope=Main_Wing_Slot_Slope, round=true, radius=Main_Wing_Slot_Radius, taper=Main_Wing_Slot_Taper);
        diff()
            cuboid([Main_Wing_Slot_Width+4,Main_Wing_Slot_Length+Main_Wing_Slot_EntryLength+4,Main_Wing_Slot_Height+4], anchor=BOT)
            attach(TOP,BOT,align=BACK,inside=true,inset=2)
                tag("remove") dovetail("female", slide=Main_Wing_Slot_Length, width=Main_Wing_Slot_Width, height=Main_Wing_Slot_Height, slope=Main_Wing_Slot_Slope, entry_slot_length=Main_Wing_Slot_EntryLength, round=true, radius=Main_Wing_Slot_Radius, taper=Main_Wing_Slot_Taper);
    }

/*
  left(Main_Wing_Average_Chord){  
    cuboid([Main_Wing_Average_Chord,Main_Wing_Slot_Width+4,2])
        right(Main_Wing_SlotOffset) attach(TOP) dovetail("male", slide=Main_Wing_SlotLength, width=Main_Wing_Slot_Width, height=Main_Wing_Slot_Height
            , back_width=Main_Wing_Slot_Width-Main_Wing_Slot_Taper
            , spin=90
            , round=true, radius=Main_Wing_Slot_Radius);
    fwd(35)
    diff("remove")
        cuboid([Main_Wing_Average_Chord,Main_Wing_Slot_Width+4,Main_Wing_Slot_Height+2])
        right(Main_Wing_SlotOffset) tag("remove") attach(BOTTOM) up(Main_Wing_Slot_Height/2) yrot(1.2) dovetail("female", slide=Main_Wing_SlotLength, width=Main_Wing_Slot_Width, height=Main_Wing_Slot_Height
            , back_width=Main_Wing_Slot_Width-Main_Wing_Slot_Taper
            , spin=90
            , round=true, radius=Main_Wing_Slot_Radius);
  }
  */
}
else
if ($preview && Preview_BuiltModel) { 
    // Preview mode - show complete model
   xrot(90){
        up(fuselage_rod_od.x/2) main_wing();
        zflip() up(fuselage_rod_od.x/2) main_wing();

        Rear_Wing();
        zflip() Rear_Wing();

        Fuselage();
   }
}
else 
{
    // Render mode - split into printable parts using wing configuration
    // DIAGNOSTIC: Test if hollow wing construction is causing the freeze
    echo("=== RENDER MODE DIAGNOSTIC ===");
    echo(str("Use_Hollow_Wing_Construction: ", Use_Hollow_Wing_Construction));
    echo(str("Number of spar configs: ", len(main_wing_spar_config.spars)));
    echo(str("Number of individual spar holes: ", len(generate_spar_holes(main_wing_spar_config, main_wing_config))));
    echo("Starting render...");
    
    split_print(main_wing_config.print) main_wing();
}

// CARBON SPAR SYSTEM

//Calculate the 2d projection of the wing which defines its area
// Note: Use this module to render and measure the wing area
module visualize_actual_wing_area(wing_config) {
    xrot(-90) projection() xrot(90) CreateWing(wing_config);
}

// Minimum trailing edge thickness for 3D printing
module visualize_wing_area_calculation(wing_config) {
    steps = 100; // Fewer steps for visualization
    step_size = wing_config.wing_mm / steps;
    
    // Apply the same translation as CreateWing uses
   // translate([get_root_chord_mm(wing_config) * wing_config.center_line_nx, 0, 0]) {
        for (i = [0:steps-1]) {
            position = i * step_size;
            chord = WingSliceChordLength(position / wing_config.wing_mm, wing_config.chord_profile);
            
            color([1, 0.5, 0, 0.3]) // Semi-transparent orange
            //translate([-wing_config.center_line_nx * chord, 0, position])
                cube([chord, 0.5, step_size], anchor=BOTTOM+LEFT);
        }
   // }
}

// Function to calculate actual wing area by numerical integration
// Takes a wing configuration object to work with any wing (main or stabilizer)
function calculate_actual_wing_area(wing_config) = 
    let(
        // Number of integration steps (higher = more accurate)
        steps = 250,
        step_size = wing_config.wing_mm / steps,
        
        // Calculate area by summing chord lengths at each position
        area_values = [for (i = [0:steps-1])
            let(
                position = i * step_size,
                // Use midpoint for better accuracy and existing WingSliceChordLength function
                nz = (position + step_size/2) / wing_config.wing_mm,
                chord_at_position = WingSliceChordLength(nz, wing_config.chord_profile)
            ) chord_at_position * step_size
        ],
        
        // Sum all area elements
        area_sum = sum(area_values)
    ) area_sum * 2; // Multiply by 2 for full wing (both halves)



