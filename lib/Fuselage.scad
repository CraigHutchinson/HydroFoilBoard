
/*
 * Fuselage Creator Module
 * 
 * This module creates parametric hydrofoil fuselages based on AXIS PNG 1150 specifications.
 * Supports multiple fuselage types with spar-through design for 3D printing.
 * 
 * Uses functional approach with cross-section profiles for efficiency.
 * Depends on BOSL2 library for advanced geometric operations.
 */

include <BOSL2/std.scad>

// FUSELAGE SYSTEM
// Function to calculate fuselage length based on type
function get_fuselage_length() = 
    let(
        lengths = [
            765,  // Standard
            685,  // Short  
            605,  // Ultrashort
            525   // Crazyshort
        ]
    ) lengths[fuselage_type - 1] * Build_Scale;

// Function to create fuselage cross-section profile
function fuselage_cross_section(position_ratio) = 
    let(
        // Calculate taper factor based on position along fuselage
        taper_factor = 1 - (position_ratio * (1 - fuselage_taper_ratio)),
        
        // Calculate dimensions at this position
        width = fuselage_width * taper_factor * Build_Scale,
        height = fuselage_height * taper_factor * Build_Scale,
        
        fuselage_length = get_fuselage_length(),

        square_rod = true,

        // Square section transition ratio (0 = square, 1 = streamlined)
        square_section_length = (Main_Wing_Root_Chord_MM) / fuselage_length,
        
        // Create profile that transitions from square to streamlined
        profile = (square_rod || position_ratio < square_section_length) ?
            // Square cross-section for wing section
            [
                [-width/2, -height/2],
                [-width/2, height/2],
                [width/2, height/2],
                [width/2, -height/2]
            ] :
            // Interpolated profile transitioning to streamlined hexagon
            [
                [-width/2, 0],
                [-width/4, height/2],
                [width/4, height/2],
                [width/2, 0],
                [width/4, -height/2],
                [-width/4, -height/2]
            ]
    ) profile;

/**
 * Main fuselage creation module
 * Generates the complete fuselage using BOSL2 functions
 */
module Fuselage() {
    fuselage_length = get_fuselage_length();
    fuselage_sections = max(10, fuselage_length / 20); // Adaptive section count
    
    // Create fuselage profiles for each section
    profiles = [
        for (i = [0:fuselage_sections]) let(
            position_ratio = i / fuselage_sections,
            x_pos = position_ratio * fuselage_length,
            cross_section = fuselage_cross_section(position_ratio)
        ) path3d(cross_section, x_pos)
    ];
    
    // Create the fuselage surface using BOSL2 skin() function
    difference() {
        yrot(90) skin(profiles, slices=0, refine=1, method="reindex", sampling="segment");
        
        // Create spar holes through fuselage (penetrate Y-axis, span-wise)
        if (spar_through_fuselage) {
            for (spar = spar_holes) {
                translate([spar.x, spar.offset,0 ]) {
                    cylinder(d=spar.hole_diameter + (spar_hole_void_clearance * 2), 
                                h=spar.length * 2 * Build_Scale, center=true);
                    
                }
            }
        }
        
        // Create mast connection hole (penetrate Z-axis, vertical)
        translate([fuselage_length * 0.4, 0, 0]) {
            xrot(90) cylinder(d=mast_connection_diameter, h=mast_connection_length, center=true);
            
        }
    }
}