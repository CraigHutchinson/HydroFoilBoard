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
// Based on Foil Axis PNG 1150 specifications
wing_span = 1150;               // Total wing span in mm
wing_aspectratio = 7.72;        // Wing aspect ratio
wing_chord = wing_span / wing_aspectratio; // TODO: PNG 1150 has 180mm chord, deeper in middle

// Wing dimensions
// Number of wing sections (more = higher resolution)
wing_sections = $preview ? 20 : 75; // [10:5:150]
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

// Wing anhedral settings
// Angle of anhedral at tip (degrees)
wing_anhedral_deg = 1; // [0:0.5:10]
// Where anhedral starts (percentage from root)
wing_anhedral_start_perc = 50; // [0:100]

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
af_vec_top = [for (i = af_vec_slice) [i.x, i.y]];       // Top surface line
af_vec_bottom = [for (i = af_vec_slice) [i.x, i.z]];    // Bottom surface line

// Mean camber line - midline halfway between top and bottom surfaces
af_vec_mean_camber = [for (i = [0 : len(af_vec_top) - 1]) (af_vec_top[i] + af_vec_bottom[i]) / 2];

// Airfoil bounding box
af_bbox = airfoil_E818_range();

// Airfoil slice module
module airfoil_E818_slice() {
    polygon(points=af_vec_mean_camber);
}

// Wing airfoil modules
module RootAirfoilPolygon() {
    airfoil_E818();
}

module MidAirfoilPolygon() {
    airfoil_E818();
}

module TipAirfoilPolygon() {
    airfoil_E818();
}

// CARBON SPAR SYSTEM
// Function to create a new spar configuration
// perc: Percentage from leading edge
// diam: Size of the spar hole
// length: Length of the spar in mm
// offset: Adjust where the spar is located
function new_spar(perc, diam, length, offset) = [
    perc,
    diam * Build_Scale,
    length * Build_Scale,
    offset * Build_Scale
];

// Spar accessor functions
function spar_hole_perc(spar) = spar[0];
function spar_hole_size(spar) = spar[1];
function spar_hole_length(spar) = spar[2];
function spar_hole_offset(spar) = spar[3];

// Spar hole configurations
// TODO: Use af_vec_mean_camber for offset calculations
spar_holes = [
    new_spar(15, 4.0, 250, 0.25),
    new_spar(30, 4.0, 400, 0.75),
    new_spar(45, 5.0, 450, 1.25),
    new_spar(60, 5.0, 450, 1.75),
    new_spar(75, 4.0, 400, 2.0)
];

spar_hole_void_clearance = 0.0;  // Clearance for spar to grid interface (at least double extrusion width)

// LIBRARY INCLUDES

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
/*else if (add_inner_grid == false && spar_hole == true) {
    echo("ERROR: add_inner_grid needs to be true for spar_hole to be true");
}*/

// Main execution
if ($preview && Build_Preview) {
    // Preview mode - show complete model
    main_wing();
    zflip() main_wing();
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