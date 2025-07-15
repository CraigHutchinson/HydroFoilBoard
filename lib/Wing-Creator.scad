/*
 * Wing Creator Module
 * 
 * This module creates parametric hydrofoil wings with support for:
 * - Multiple airfoil sections (root, mid, tip)
 * - Washout (twist) for stability
 * - Elliptical and tapered planforms
 * - Adjustable chord lengths and transitions
 * 
 * Uses BOSL2 skin() function for smooth, efficient wing generation
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
 * Returns the appropriate airfoil path based on wing position
 * @param index - Current slice index along the wing span
 * @param wing_sections - Total number of sections in the wing
 */
function GetAirfoilPath(index, wing_sections) = 
    let(
        tip_airfoil_change_index = wing_sections * (tip_airfoil_change_perc / 100),
        center_airfoil_change_index = wing_sections * (center_airfoil_change_perc / 100)
    )
    // Return appropriate airfoil path based on position
    (index > tip_airfoil_change_index) ? TipAirfoilPath() :
    (index > center_airfoil_change_index) ? MidAirfoilPath() :
    RootAirfoilPath();

/**
 * Returns a scaled and positioned airfoil path for a wing slice
 * @param index - Current slice index along the wing span
 * @param z_location - Z position of this slice along the wing
 * @param wing_sections - Total number of sections in the wing
 */
function WingSlicePath(index, z_location, wing_sections) = 
    let(
        // Calculate chord length at this position based on wing mode
        current_chord_mm = (wing_mode == 1) 
            ? ChordLengthAtIndex(index, wing_sections)
            : ChordLengthAtEllipsePosition((wing_mm + 0.1), wing_root_chord_mm, z_location),
        
        // Scale factor based on chord length (normalized to 100mm base)
        scale_factor = current_chord_mm / 100,
        
        // Get the base airfoil path
        base_path = GetAirfoilPath(index, wing_sections),
        
        // Apply scaling and translation
        scaled_path = [for (pt = base_path) 
            [pt[0] * scale_factor - wing_center_line_perc / 100 * current_chord_mm, 
             pt[1] * scale_factor]
        ],
        
        // Apply washout rotation if needed
        final_path = (washout_deg > 0 && 
            ((wing_mode > 1 && index > WashoutStart(0, wing_sections, washout_start, wing_mm)) ||
             (wing_mode == 1 && index > (wing_sections * (washout_start / 100))))) ?
            ApplyWashoutToPath(scaled_path, index, current_chord_mm, wing_sections) :
            scaled_path
    ) final_path;

/**
 * Applies washout rotation to an airfoil path
 * @param path - The 2D airfoil path to rotate
 * @param index - Current slice index
 * @param current_chord_mm - Chord length at this position
 * @param wing_sections - Total number of sections
 */
function ApplyWashoutToPath(path, index, current_chord_mm, wing_sections) =
    let(
        // Calculate washout parameters
        washout_start_point = (wing_mode == 1) 
            ? (wing_sections * (washout_start / 100))
            : WashoutStart(0, wing_sections, washout_start, wing_mm),
        
        washout_deg_frac = washout_deg / (wing_sections - washout_start_point),
        washout_deg_amount = (washout_start_point - index) * washout_deg_frac,
        rotate_point = current_chord_mm * (washout_pivot_perc / 100),
        
        // Apply 2D rotation around the pivot point
        rotated_path = [for (pt = path) 
            let(
                // Translate to rotate around pivot point
                translated_pt = [pt[0] - rotate_point, pt[1]],
                // Apply rotation
                rotated_pt = [
                    translated_pt[0] * cos(washout_deg_amount) - translated_pt[1] * sin(washout_deg_amount),
                    translated_pt[0] * sin(washout_deg_amount) + translated_pt[1] * cos(washout_deg_amount)
                ],
                // Translate back
                final_pt = [rotated_pt[0] + rotate_point, rotated_pt[1]]
            ) final_pt
        ]
    ) rotated_path;
    
/**
 * Main wing creation module
 * Generates the complete wing using BOSL2 skin() function
 */
module CreateWing() {
    wing_section_mm = wing_mm / wing_sections;
    
    translate([wing_root_chord_mm * (wing_center_line_perc / 100), 0, 0]) {
        // Create wing profiles for each section
        profiles = [
            for (i = [0:wing_sections]) let(
                z_pos = (wing_mode == 1) ? wing_section_mm * i : f(i, wing_sections, wing_mm)
            ) path3d(WingSlicePath(i, z_pos, wing_sections), z_pos)
        ];
        
        // Create the wing surface using BOSL2 skin() function
        skin(profiles, slices=0, refine=1, method="reindex", sampling="segment");
    }
}