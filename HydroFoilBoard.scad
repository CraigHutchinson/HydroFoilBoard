include <bosl2/std.scad>


// HYDROFOIL BOARD WING GENERATOR
// RC wing generator for Vase mode printing
//
// Prior work used to create this script:
// https://www.thingiverse.com/thing:3506692
// https://github.com/guillaumef/openscad-airfoil
// https://github.com/Beachless/Vase-Wing


/* [Hidden] */

    Printer_BuildArea = [250, 250, 250]; // Printer build area in mm

/* [Global Rendering Settings] */
// 360deg/5(faceAngle) = 72 facets (affects performance and object smoothness)
Render_Mode_Facet_Angle = 1; // [1:1:10]
// Minimum facet size for rendering (NOTE: coarse value is udef for preview mode)
Render_Mode_Facet_Size = 0.2; // [0.1:0.1:1.0]


$fa = $preview ? 10 : Render_Mode_Facet_Angle;            // 360deg/5($fa) = 60 facets (affects performance and object smoothness)
$fs = $preview ? 1 : Render_Mode_Facet_Size;       // Min facet size (lower for final render)

/* [Build Configuration] */
// Render test parts for checking 3D printing settings
// This will create a test part for each component to check printability and settings
Build_TestParts = false; // [true:false]

// Preview mode: view Complete model built
Preview_BuiltModel = true; // [true:false]

// Scale factor (1/3.33 for 1.5 rods, 5/3.33 = 1.5 rods) 
Build_Scale = 1.0; // [0.1:0.1:3.0] 

/* [Design+Print Settings] */
// Enable vase mode printing optimizations
Design_For_VaseMode = false;
// Interface and gap width values
slice_ext_width = 0.6; // [0.1:0.1:2.0]
// Gap in outer skin (smaller is better, limited by slicer)
slice_gap_width = 0.02; // [0.01:0.01:0.5] 

/* [Wing Geometry Settings] */
// Based on AXIS PNG 1150 specifications
wing_span = 1150;               // Total wing span in mm
wing_aspectratio = 7.72;        // Wing aspect ratio
wing_area = 1713;               // Wing area in cm²
wing_chord = wing_span / wing_aspectratio; // PNG 1150 has 149mm avg chord (1150/7.72)

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

// Wing dimensions
// Number of wing sections (more = higher resolution)
wing_sections = $preview ? 20 : 100; // [10:5:150]
wing_mm = (wing_span / 2) * Build_Scale;         // Wing length in mm (half span)
wing_root_chord_mm = wing_chord * Build_Scale;   // Root chord length in mm
// Wing tip chord length in mm (not relevant for elliptic wing)
wing_tip_chord_mm = 50 * Build_Scale; // [10:5:200]

// Wing shape settings
wing_mode = 2; // [1:"Trapezoidal Wing", 2:"Elliptic Wing"]

// Power of the elliptic wing (2 = perfect ellipse)
wing_eliptic_pow = 1.5; // [1.0:0.1:3.0]
// Percentage from leading edge for wing center line
wing_center_line_perc = 90; // [0:100]

// Wing anhedral settings (degrees)
// Anhedral creates a downward angle of the wing tips for improved stability
// This defines the angle of the anhedral at the tip of the wing (degrees)
Wing_Anhedral_Degrees = 0.5; // [0:0.2:10]
// Where anhedral starts (percentage from root)
// This defines where the anhedral starts along the span - wing sections are rotated around x-axis and offset in y
Wing_Anhedral_Start_At_Percentage = 50; // [0:100]

/* [Airfoil Settings] */
// Where to change to center airfoil (100 = off)
center_airfoil_change_perc = 100; // [0:100]
// Where to change to tip airfoil (100 = off)
tip_airfoil_change_perc = 100; // [0:100]
// Number of slices for airfoil blending (0 = off)
slice_transisions = 0; // [0:1:20]

/* [Wing Washout Settings] */
// Degrees of washout (0 = none)
washout_deg = 1.5; // [0:0.1:10]
// Where washout starts (mm from root)
washout_start = 60 * Build_Scale; // [0:10:500]
// Washout pivot point (percentage from LE)
washout_pivot_perc = 25; // [0:100]

/* [Internal Grid Structure Settings] */
// Add inner grid for 3D printing (!Print_For_VaseMode)
add_inner_grid = false;
// 1=diamond grid, 2=spar and cross spars
grid_mode = 1;
// Add holes to ribs to decrease weight
create_rib_voids = false;

// Grid Mode 1 Settings (Diamond Grid)
// Changes the size of inner grid blocks
grid_size_factor = 2; // [1:1:10]

// Grid Mode 2 Settings (Spar and Cross Spars)
// Number of spars
spar_num = 3; // [1:1:10]
// Offset spars from LE/TE
spar_offset = 15; // [0:5:50]
// Number of ribs
rib_num = 6; // [1:1:20]
// Rib offset
rib_offset = 1; // [0:1:10]

/* [Hidden] */
// AIRFOIL DEFINITIONS
// Module for root airfoil polygon
// TODO: e817 looks good but not in DB presently
include <lib/openscad-airfoil/e/e818.scad>

// Minimum trailing edge thickness for 3D printing compatibility
min_trailing_edge_thickness = 0.25; // mm

// Function to modify airfoil data for 3D printing compatibility
// This function modifies both path and slice data consistently
function modify_airfoil_for_printing(original_slice, min_thickness = 0.3) = 
    let(
        // Modify each slice point
        modified_slice = [for (iSlice = original_slice)
            let(
                slice_perc = iSlice.x,
                slice_top = iSlice.y,
                slice_bottom = iSlice.z,
                                
                // Get current thickness
                current_thickness = abs(slice_top - slice_bottom),
                
                // Calculate thickness adjustment needed
                thickness_adjustment = current_thickness < min_thickness ? 
                    (min_thickness - current_thickness) / 2 : 0,

                // Apply modification to upper and lower surfaces
                modified_top = slice_top + thickness_adjustment,
                modified_bottom = slice_bottom - thickness_adjustment
            ) [slice_perc, modified_top, modified_bottom]
        ]
    ) modified_slice;

// Get original airfoil data
af_vec_slice_original = airfoil_E818_slice();

// Modify airfoil slice data for 3D printing
af_vec_slice = modify_airfoil_for_printing(af_vec_slice_original, min_trailing_edge_thickness);

// Extract surface lines from modified slice data
af_vec_top = [for (i = af_vec_slice) [i.x, i.y]];       // Top surface line
af_vec_bottom = [for (i = af_vec_slice) [i.x, i.z]];    // Bottom surface line

// Function to create airfoil path from top and bottom surface lines
function create_airfoil_path_from_surfaces(top_surface, bottom_surface) = 
    let(
        // Reverse bottom surface to create continuous path
        bottom_reversed = [for (i = [len(bottom_surface) - 1 : -1 : 0]) bottom_surface[i]],
        
        // Combine top and bottom surfaces into single path
        combined_path = concat(top_surface, bottom_reversed)
    ) combined_path;

// Create airfoil paths from modified surface data
af_vec_path_root = create_airfoil_path_from_surfaces(af_vec_top, af_vec_bottom);
af_vec_path_mid = af_vec_path_root;
af_vec_path_tip = af_vec_path_root;

// Mean camber line - midline halfway between top and bottom surfaces
af_vec_mean_camber = [for (i = af_vec_slice) [i.x, (i.y + i.z) / 2]];

// Airfoil bounding box
af_bbox = airfoil_E818_range();

// AIRFOIL PATH FUNCTIONS FOR BOSL2 SKIN
// These functions return airfoil path data that can be used with BOSL2's skin() function

/**
 * Returns the root airfoil path as a 2D point array
 * Suitable for use with BOSL2 skin() function
 */
function RootAirfoilPath() = af_vec_path_root;

/**
 * Returns the mid airfoil path as a 2D point array
 * Suitable for use with BOSL2 skin() function
 */
function MidAirfoilPath() = af_vec_path_mid;

/**
 * Returns the tip airfoil path as a 2D point array
 * Suitable for use with BOSL2 skin() function
 */
function TipAirfoilPath() = af_vec_path_tip;

// CARBON SPAR SYSTEM
// Function to create a new spar configuration
// perc: Percentage from leading edge
// diam: Size of the spar hole
// length: Length of the spar in mm
// offset: Optional manual offset override (if not provided, uses calculated offset)
function new_spar(perc, diam, length, offset, offset_from=undef) = [
    perc,
    diam * Build_Scale,
    length * Build_Scale,
    ((offset_from != undef ? calculate_spar_offset_at_chord_position(perc, offset_from) : 0) + offset) * Build_Scale
];

// Spar accessor functions
function spar_hole_perc(spar) = spar[0];
function spar_hole_size(spar) = spar[1];
function spar_hole_length(spar) = spar[2];
function spar_hole_offset(spar) = spar[3];

// Spar hole configurations
// Uses calculated offsets based on mean camber line for optimal structural positioning
spar_holes = [
    // Full-span Spars go through, the wing but are split at the center line (May optionally be glued into the wing structure)
    new_spar(10, 2.0, 300, 0.5, "MIDDLE"),
    new_spar(15, 2.0, 250, -2.5, "TOP"), new_spar(15, 2.0, 250, 3.25, "BOTTOM"),
    new_spar(35, 2.0, 300, -2.5, "TOP"), new_spar(35, 2.0, 450, 3, "BOTTOM"),
    new_spar(55, 2.0, 300, -3, "TOP"), new_spar(55, 2.0, 450, 3, "BOTTOM"),
    new_spar(75, 2.0, 400, -1.0, "MIDDLE"),

    // Full-span Spars go through the fuselage as one piece
    new_spar(25, 4.0, 400, 0.5),
    new_spar(45, 4.0, 400, 1.75),
    new_spar(65, 4.0, 400, 3.0)
];

spar_hole_void_clearance = 0.0;  // Clearance for spar to grid interface (at least double extrusion width)

// LIBRARY INCLUDES

include <lib/Fuselage.scad>
include <lib/Grid-Structure.scad>
include <lib/Grid-Void-Creator.scad>
include <lib/Helpers.scad>
include <lib/Rib-Void-Creator.scad>
include <lib/Spar-Hole.scad>
include <lib/Wing-Creator.scad>

// MAIN WING MODULE
module main_wing() {
    difference() {
        difference() {
            CreateWing();

            if (add_inner_grid) {
                union() {
                    difference() {
                        difference() {
                            if (grid_mode == 1) {
                                StructureGrid(wing_mm, wing_root_chord_mm, grid_size_factor);
                            } else {
                                StructureSparGrid(wing_mm, wing_root_chord_mm, grid_size_factor, spar_num, spar_offset,
                                                  rib_num, rib_offset);
                            }
                            union() {
                                if (grid_mode == 1) {
                                    if (create_rib_voids) {
                                        CreateRibVoids();
                                    }
                                } else {
                                    if (create_rib_voids) {
                                        CreateRibVoids2();
                                    }
                                }
                                union() {
                                    for (spar = spar_holes) {
                                        CreateSparVoid(spar);
                                    }
                                }
                            }
                        }
                        CreateGridVoid();
                    }
                }
            }
        }
        union() {
            for (spar = spar_holes) {
                CreateSparHole(spar);
            }
        }
    }
}

// VALIDATION AND MAIN EXECUTION
// Input validation
if (wing_sections * 0.2 < slice_transisions) {
    echo("ERROR: You should lower the amount of slice_transisions.");
} else if (center_airfoil_change_perc < 0 || center_airfoil_change_perc > 100) {
    echo("ERROR: center_airfoil_change_perc has to be in a range of 0-100.");
}

// Display PNG 1150 specifications
echo(str("=== AXIS PNG 1150 Specifications ==="));
echo(str("Wing Span: ", wing_span, "mm"));
echo(str("Wing Area: ", wing_area, "cm²"));
echo(str("Aspect Ratio: ", wing_aspectratio));
echo(str("Average Chord: ", wing_chord, "mm"));
echo(str("Fuselage Length: ", get_fuselage_length(), "mm"));
echo(str("Fuselage Type: ", 
    fuselage_type == 1 ? "Standard (765mm)" :
    fuselage_type == 2 ? "Short (685mm)" :
    fuselage_type == 3 ? "Ultrashort (605mm)" :
    "Crazyshort (525mm)"
));
echo(str("Fuselage Width: ", fuselage_width, "mm"));
echo(str("Fuselage Height: ", fuselage_height, "mm"));
echo(str("Spar Through Design: ", spar_through_fuselage ? "Yes" : "No"));
echo(str("Number of Spars: ", len(spar_holes)));
echo(str("Build Scale: ", Build_Scale, "x"));
echo(str("Scaled Wing Half-Span: ", wing_mm, "mm"));
echo(str("====================================="));

/*else if (add_inner_grid == false && spar_hole == true) {
    echo("ERROR: add_inner_grid needs to be true for spar_hole to be true");
}*/

// Main execution
if(Build_TestParts) {
    // Print the lower 1mm of each wing part
    split_into_parts(wing_mm, Printer_BuildArea, Build_Scale, af_bbox, 5) main_wing();
    
    fwd(20) yrot(90) left(wing_chord*Build_Scale/2+1)  split_into_parts(wing_mm, Printer_BuildArea, Build_Scale, af_bbox) intersection() { 
        main_wing();
        right(wing_chord*Build_Scale/2) cube([2,100, wing_mm*Build_Scale], anchor=BOTTOM+CENTER);
    }
}
else
if ($preview && Preview_BuiltModel) {
    // Preview mode - show complete model
   % main_wing();
   % zflip() main_wing();
    Fuselage();
}
else 
{

    // Render mode - split into printable parts
    split_into_parts(wing_mm, Printer_BuildArea, Build_Scale, af_bbox) main_wing();
}

// CARBON SPAR SYSTEM
// Function to calculate the ideal spar offset based on mean camber line
// perc: Percentage from leading edge (0-100)
// Returns the y-offset at that chord position for optimal structural positioning
function calculate_spar_offset_at_chord_position(perc, line="MID", position_mm = 0) = 
    let(
        // Since data is sorted by x-coordinate, find the first point >= target
        target_x = perc,
        
        af_vec = line=="TOP" ? af_vec_top :
                 line=="BOTTOM" ? af_vec_bottom :
                 af_vec_mean_camber, //< undef == af_vec_mean_camber
        
        // Simple linear search for the closest point (efficient for small datasets)
        closest_index = 
            target_x <= af_vec[0][0] ? 0 :
            target_x >= af_vec[len(af_vec)-1][0] ? len(af_vec)-1 :
            // Find first point where x >= target_x
            [for (i = [0 : len(af_vec) - 1]) 
                if (af_vec[i][0] >= target_x) i][0],
        
        // Get the y-coordinate at that position
        y_offset = af_vec[closest_index][1]
    ) y_offset * WingSliceScaleFactorByPosition(position_mm); // Scale the offset based on the current wing slice scale factor

// Function to calculate wing slice scale factor based on position
function WingSliceScaleFactorByPosition(position_mm) = 
    let(
        // Calculate chord at this position using elliptic distribution
        current_chord = (wing_mode == 1) 
            ? ChordLengthAtPosition(position_mm)
            : ChordLengthAtEllipsePosition(wing_mm, wing_root_chord_mm, position_mm),
        
        // Scale factor normalized to 100mm base chord
        scale_factor = current_chord / 100
    ) scale_factor;
