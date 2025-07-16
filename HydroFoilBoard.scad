include <bosl2/std.scad>


// HYDROFOIL BOARD WING GENERATOR
// RC wing generator for Vase mode printing
//
// Prior work used to create this script:
// https://www.thingiverse.com/thing:3506692
// https://github.com/guillaumef/openscad-airfoil
// https://github.com/Beachless/Vase-Wing


/* [Hidden] */

/* [Global Rendering Settings] */
// 360deg/5(faceAngle) = 72 facets (affects performance and object smoothness)
Render_Mode_Facet_Angle = 1; // [1:1:10]
// Minimum facet size for rendering (NOTE: coarse value is udef for preview mode)
Render_Mode_Facet_Size = 0.2; // [0.1:0.1:1.0]

$fa = $preview ? 10 : Render_Mode_Facet_Angle;            // 360deg/5($fa) = 60 facets (affects performance and object smoothness)
$fs = $preview ? 1 : Render_Mode_Facet_Size;       // Min facet size (lower for final render)

/* [Build Configuration] */
// Complete model build view (preview mode only)
Build_Preview = true;

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
fuselage_width = 19;            // Fuselage width (horizontal dimension) in mm
fuselage_height = 12;           // Fuselage height (vertical dimension) in mm
fuselage_taper_ratio = 0.8;     // Taper ratio from root to tip

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

// Airfoil path vectors
af_vec_path_root = airfoil_E818_path();
af_vec_path_mid = airfoil_E818_path();
af_vec_path_tip = airfoil_E818_path();

// Airfoil slice data
af_vec_slice = airfoil_E818_slice();

// Surface line vectors
//af_vec_top = [for (i = af_vec_slice) [i.x, i.y]];       // Top surface line
//af_vec_bottom = [for (i = af_vec_slice) [i.x, i.z]];    // Bottom surface line

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
// offset: Adjust where the spar is located
function new_spar(perc, diam, length, offset=0) = [
    perc,
    diam * Build_Scale,
    length * Build_Scale,
    ((calculate_spar_offset_at_chord_position(perc)* WingSliceScaleFactorByPosition(0)) + offset) * Build_Scale 
];

// Spar accessor functions
function spar_hole_perc(spar) = spar[0];
function spar_hole_size(spar) = spar[1];
function spar_hole_length(spar) = spar[2];
function spar_hole_offset(spar) = spar[3];

// Spar hole configurations
// Uses calculated offsets based on mean camber line for optimal structural positioning
spar_holes = [
    new_spar(15, 4.0, 250, 0),
    new_spar(30, 4.0, 400, 0),
    new_spar(45, 5.0, 400, -1.25),
    new_spar(60, 5.0, 400, -1.25),
    new_spar(75, 4.0, 400, -1.0)
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
              #  CreateSparHole(spar);
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
if ($preview && Build_Preview) {
    // Preview mode - show complete model
   % main_wing();
   % zflip() main_wing();
    Fuselage();
} else {
    // Render mode - split into printable parts
    splits = ceil(wing_mm / (250 * Build_Scale));
    splits_length = wing_mm / splits;

    for (i = [0:splits-1]) {
        fwd(i * (af_bbox.w - af_bbox.z + (200 / (splits - 1))))
        intersection() {
            down(i * splits_length) main_wing();
            cube([250, 250, splits_length], anchor=BOTTOM+LEFT);
        }
    }
}

// CARBON SPAR SYSTEM
// Function to calculate the ideal spar offset based on mean camber line
// perc: Percentage from leading edge (0-100)
// Returns the y-offset at that chord position for optimal structural positioning
function calculate_spar_offset_at_chord_position(perc) = 
    let(
        // Since data is sorted by x-coordinate, find the first point >= target
        target_x = perc,
        
        // Simple linear search for the closest point (efficient for small datasets)
        closest_index = 
            target_x <= af_vec_mean_camber[0][0] ? 0 :
            target_x >= af_vec_mean_camber[len(af_vec_mean_camber)-1][0] ? len(af_vec_mean_camber)-1 :
            // Find first point where x >= target_x
            [for (i = [0 : len(af_vec_mean_camber) - 1]) 
                if (af_vec_mean_camber[i][0] >= target_x) i][0],
        
        // Get the y-coordinate at that position
        y_offset = af_vec_mean_camber[closest_index][1]
    ) y_offset;

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
