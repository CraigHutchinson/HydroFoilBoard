/*
 * Wing Creator Module
 * 
 * This module creates parametric hydrofoil wings with support for:
 * - Multiple airfoil sections (root, mid, tip)
 * - Washout (twist) for stability
 * - Elliptical and tapered planforms
 * - Adjustable chord lengths and transitions
 * 
 * Uses 2D airfoil polygons and hull operations for efficient wing generation
 * Depends on BOSL2 library for advanced geometric operations
 */

include <BOSL2/std.scad>

/**
 * Creates a wing slice with washout (twist) applied
 * 
 * @param index - Current slice index along the wing span
 * @param current_chord_mm - Chord length at this position in mm
 * @param wing_sections - Total number of sections in the wing
 */
module WashoutSlice(index, current_chord_mm, wing_sections) {
    // Calculate where washout begins based on wing mode
    washout_start_point = (wing_mode == 1) 
        ? (wing_sections * (washout_start / 100))
        : WashoutStart(0, wing_sections, washout_start, wing_mm);
    
    // Calculate incremental washout angle per section
    washout_deg_frac = washout_deg / (wing_sections - washout_start_point);
    
    // Calculate washout amount for this specific slice
    washout_deg_amount = (washout_start_point - index) * washout_deg_frac;
    
    // Determine pivot point for rotation based on chord percentage
    rotate_point = current_chord_mm * (washout_pivot_perc / 100);

    // Apply washout rotation around the pivot point (2D rotation around Z axis)
    translate([rotate_point, 0, 0]) 
        rotate([0, 0, washout_deg_amount]) 
            translate([-rotate_point, 0, 0])
                Slice(index, wing_sections);
}

/**
 * Creates a wing slice with appropriate airfoil based on position
 * Handles transitions between root, mid, and tip airfoils
 * 
 * @param index - Current slice index along the wing span
 * @param wing_sections - Total number of sections in the wing
 */
module Slice(index, wing_sections) {
    // Calculate transition points for different airfoil sections
    tip_airfoil_change_index = wing_sections * (tip_airfoil_change_perc / 100);
    center_airfoil_change_index = wing_sections * (center_airfoil_change_perc / 100);

    // Tip airfoil transition region
    if (tip_airfoil_change_perc < 100 && 
        (index > (tip_airfoil_change_index - slice_transisions) &&
         index < (tip_airfoil_change_index + slice_transisions))) {
        
        // Create smooth transition between mid and tip airfoils
        projection() {
            intersection() {
                hull() {
                    translate([0, 0, -10]) 
                        linear_extrude(height = 0.00000001, slices = 0) 
                            MidAirfoilPolygon();
                    
                    translate([0, 0, 10]) 
                        linear_extrude(height = 0.00000001, slices = 0) 
                            TipAirfoilPolygon();
                }
            }
        }
    }
    // Pure tip airfoil region
    else if (index > tip_airfoil_change_index) {
        TipAirfoilPolygon();
    }
    // Center airfoil transition region
    else if (center_airfoil_change_perc < 100 && 
             (index > (center_airfoil_change_index - slice_transisions) &&
              index < (center_airfoil_change_index + slice_transisions))) {
        
        // Create smooth transition between root and mid airfoils
        projection() {
            intersection() {
                hull() {
                    translate([0, 0, -10]) 
                        linear_extrude(height = 0.00000001, slices = 0) 
                            RootAirfoilPolygon();
                    
                    translate([0, 0, 10]) 
                        linear_extrude(height = 0.00000001, slices = 0) 
                            MidAirfoilPolygon();
                }
            }
        }
    }
    // Mid airfoil region
    else if (index > center_airfoil_change_index) {
        MidAirfoilPolygon();
    }
    // Root airfoil region
    else {
        RootAirfoilPolygon();
    }
}

/**
 * Creates a 2D wing slice polygon at a specific position
 * Returns a pure 2D polygon for use with BOSL2 operations
 * 
 * @param index - Current slice index along the wing span
 * @param z_location - Z position of this slice along the wing (for calculations only)
 * @param wing_sections - Total number of sections in the wing
 */
module WingSlice(index, z_location, wing_sections) {
    // Calculate chord length at this position based on wing mode
    current_chord_mm = (wing_mode == 1) 
        ? ChordLengthAtIndex(index, wing_sections)
        : ChordLengthAtEllipsePosition((wing_mm + 0.1), wing_root_chord_mm, z_location);
    
    // Scale factor based on chord length (normalized to 100mm base)
    scale_factor = current_chord_mm / 100;

    // Scale and position the 2D airfoil polygon
    translate([-wing_center_line_perc / 100 * current_chord_mm, 0, 0])
        scale([scale_factor, scale_factor, 1]) {
            
            // Apply washout if conditions are met
            if (washout_deg > 0 && 
                ((wing_mode > 1 && index > WashoutStart(0, wing_sections, washout_start, wing_mm)) ||
                 (wing_mode == 1 && index > (wing_sections * (washout_start / 100))))) {
                WashoutSlice(index, current_chord_mm, wing_sections);
            }
            else {
                Slice(index, wing_sections);
            }
        }
}


/**
 * Main wing creation module
 * Generates the complete wing using hull operations between adjacent slices
 */
module CreateWing() {
    wing_section_mm = wing_mm / wing_sections;
    
    translate([wing_root_chord_mm * (wing_center_line_perc / 100), 0, 0]) {
        union() {
            for (i = [0:wing_sections-1]) {
                // Calculate Z positions based on wing mode
                z_start = (wing_mode == 1) ? wing_section_mm * i : f(i, wing_sections, wing_mm);
                z_end = (wing_mode == 1) ? wing_section_mm * (i + 1) : f(i + 1, wing_sections, wing_mm);
                
                // Create a swept section between two adjacent slices
                hull() {
                    translate([0, 0, z_start])
                        linear_extrude(height = 0.01, center = true)
                            WingSlice(i, z_start, wing_sections);
                    
                    translate([0, 0, z_end])
                        linear_extrude(height = 0.01, center = true)
                            WingSlice(i + 1, z_end, wing_sections);
                }
            }
        }
    }
}