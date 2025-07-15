include <bosl2/std.scad>


//****************Global Variables*****************//


$fa = 5; // 360deg/5($fa) = 60 facets this affects performance and object shoothness
$fs = $preview ? 1 : 0.2; // Min facet size

//Complete model view
model_view = true; 
scale = 1;// 1/3.33; //< NOTE: 5/3.33 = 1.5 rods
for_vase=false;
wing_eliptic_pow = 1.5; // This is the power of the eliptic wing. 2 is a perfect elipse
slice_ext_width = 0.6;//Used for some of the interfacing and gap width values
slice_gap_width = 0.02;//This is the gap in the outer skin.(smaller is better but is limited by what your slicer can recognise)

// Similar to Foil Axis PNG 1150
wing_span = 1150;
wing_aspectratio=7.72;
wing_chord=wing_span/wing_aspectratio; //TODO: PNG 1150 has a 180 chord as is deeper in middle

wing_sections = $preview ? 20 : 75;
wing_mm = (wing_span/2)*scale;            // wing length in mm
wing_root_chord_mm = wing_chord*scale; // Root chord legth in mm
wing_tip_chord_mm = 50*scale;   // wing tip chord length in mm (Not relevant for elliptic wing)

wing_anhedral_deg = 1; // Angle of anhedral at tip
wing_anhedral_start_perc = 50; // Where you want to anhedral to start


 // how many sections you would like to break up the wing into more is higher resolution but higher processing
wing_mode = 2; // 1=trapezoidal wing 2= elliptic wing

wing_center_line_perc = 90; // Percentage from the leading edge where you would like the wings center line

//****************Wing Airfoil settings**********//
center_airfoil_change_perc = 100; // Where you want to change to the center airfoil 100 is off
tip_airfoil_change_perc = 100;    // Where you want to change to the tip airfoil 100 is off
slice_transisions = 0; // This is the number of slices that will be a blend of airfiols when airfoil is changed 0 is off
//******//

//****************Wing Washout settings**********//
washout_deg = 1.5;         // how many degrees of washout you want 0 for none
washout_start = 60*scale;      // where you would like the washout to start in mm from root
washout_pivot_perc = 25; // Where the washout pivot point is percent from LE
//******//

add_inner_grid = false;//!for_vase; // true if you want to add the inner grid for 3d printing

grid_mode = 1;           // Grid mode 1=diamond 2= spar and cross spars
create_rib_voids = false; // add holes to the ribs to decrease weight

//****************Grid mode 1 settings**********//
grid_size_factor = 2; // changes the size of the inner grid blocks
//******//

//****************Grid mode 2 settings**********//
spar_num = 3;     // Number of spars for grid mode 2
spar_offset = 15; // Offset the spars from the LE/TE
rib_num = 6;      // Number of ribs
rib_offset = 1;   // Offset
//******//


// RC wing generator for Vase mode printing
//
// Prior work used to create this script:
// https://www.thingiverse.com/thing:3506692
// https://github.com/guillaumef/openscad-airfoil
// https://github.com/Beachless/Vase-Wing

// Module for root airfoil polygon
// TODO: e817 looks good but not in DB presently
include <lib/openscad-airfoil/e/e818.scad>

af_vec_path_root = airfoil_E818_path();
af_vec_path_mid = airfoil_E818_path();
af_vec_path_tip = airfoil_E818_path();

// Top+Bottom slices
af_vec_slice = airfoil_E818_slice();

// Top Surface line
af_vec_top = [for (i = af_vec_slice) [i.x,i.y ] ]; 

// Bottom Surface line
af_vec_bottom = [for (i = af_vec_slice) [i.x,i.z ] ]; 

//Mean Camber line - Mid line halfway between top surface and bottom surface
af_vec_mean_camber = [for (i = [0 : len(af_vec_top) - 1]) (af_vec_top[i] + af_vec_bottom[i]) / 2];

// Bounds of airfoil
af_bbox = airfoil_E818_range();
 

module airfoil_E818_slice () 
{

  polygon(points=af_vec_mean_camber);
}

// airfoil_E818_slice();

// Wing airfoils
module RootAirfoilPolygon()
{
    airfoil_E818();
}

module MidAirfoilPolygon()
{
    airfoil_E818();
}

module TipAirfoilPolygon()
{
    airfoil_E818();
}


//*******************END***************************//

// Function to create a new person
// perc Percentage from leading edge
// diam Size of the spar hole
// length lenth of the spar in mm
// offset Adjust where the spar is located
function new_spar( perc, diam, length, offset ) = [
    perc, 
    diam*scale, 
    length*scale, 
    offset*scale
];

function spar_hole_perc(spar) = spar[0];
function spar_hole_size(spar) = spar[1];
function spar_hole_length(spar) = spar[2];
function spar_hole_offset(spar) = spar[3];

//****************Carbon Spar settings**********//

// Add a spar hole into the wing
//TODO: af_vec_mean_camber for offset?
spar_holes = [
    new_spar(15, 3.0, 350, 0.25),
    new_spar(30, 4.0, 400, 0.75),
    new_spar(45, 5.0, 450, 1.25),
    new_spar(60, 5.0, 450, 1.75),
    new_spar(75, 4.0, 400, 2.0)
];                

spar_hole_void_clearance = 0.0; // Clearance for the spar to grid interface(at least double extrusion width is usually needed)
//******//

//*******************END***************************//

include <lib/Grid-Structure.scad>
include <lib/Grid-Void-Creator.scad>
include <lib/Helpers.scad>
include <lib/Rib-Void-Creator.scad>
include <lib/Spar-Hole.scad>
include <lib/Wing-Creator.scad>

module main_wing()
{
    difference()
    {
        difference()
        {
            CreateWing();

            if (add_inner_grid)
            {
                union()
                {
                    difference()
                    {
                        difference()
                        {
                            if (grid_mode == 1)
                            {
                                StructureGrid(wing_mm, wing_root_chord_mm, grid_size_factor);
                            }
                            else
                            {
                                StructureSparGrid(wing_mm, wing_root_chord_mm, grid_size_factor, spar_num, spar_offset,
                                                  rib_num, rib_offset);
                            }
                            union()
                            {
                                if (grid_mode == 1)
                                {
                                    if (create_rib_voids)
                                    {
                                        CreateRibVoids();
                                    }
                                }
                                else
                                {
                                    if (create_rib_voids)
                                    {
                                        CreateRibVoids2();
                                    }
                                }
                                union()
                                {
                                    for ( spar = spar_holes )
                                    {
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
        union()
        {
            for ( spar = spar_holes )
            {
                CreateSparHole(spar);
            }
            
        }
    }
}


if (wing_sections * 0.2 < slice_transisions)
{
    echo("ERROR: You should lower the amount of slice_transisions.");
}
else if (center_airfoil_change_perc < 0 || center_airfoil_change_perc > 100)
{
    echo("ERROR: center_airfoil_change_perc has to be in a range of 0-100.");
}
/*else if (add_inner_grid == false && spar_hole == true)
{
    echo("ERROR: add_inner_grid needs to be true for spar_hole to be true");
}*/
else
if ( $preview && model_view )
{
    main_wing();
    zflip() main_wing();
}
else //Render as parts
{
    splits = ceil(wing_mm/(250*scale));
    splits_length = wing_mm/splits;

    for ( i = [0:splits-1] )
    {    
        fwd( i * (af_bbox.w - af_bbox.z + (200/(splits-1))) )         
        intersection()
        {
            down(i*splits_length) main_wing();
            cube([250,250,splits_length], anchor=BOTTOM+LEFT);
        }
    }
}