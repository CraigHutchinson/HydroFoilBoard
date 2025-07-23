/*
 * Wing Creator Module
 * Supports multiple airfoil sections with washout (twist) for stability.
 * 
 * Uses functional approach with path-based operations for efficiency.
 * Depends on BOSL2 library for advanced geometric operations.
 */

include <BOSL2/std.scad>

/**
 * Returns the appropriate airfoil path based on wing position
 * @param z_pos - Current Z position along the wing span
 * @param wing_mm - Wing half-span length
 * @param tip_change_perc - Percentage where tip airfoil starts (default: tip_airfoil_change_perc)
 * @param center_change_perc - Percentage where center airfoil starts (default: center_airfoil_change_perc)
 */
function GetAirfoilPath(z_pos, wing_mm, tip_change_perc=undef, center_change_perc=undef) = 
    let(
        tip_perc = (tip_change_perc != undef) ? tip_change_perc : tip_airfoil_change_perc,
        center_perc = (center_change_perc != undef) ? center_change_perc : center_airfoil_change_perc,
        
        // Calculate progress along wing (0 to 1)
        progress = z_pos / wing_mm,
        
        // Convert percentages to progress values
        tip_progress = tip_perc / 100,
        center_progress = center_perc / 100,
        
        // Get base airfoil path
        base_path = (progress > tip_progress) ? TipAirfoilPath() :
                   (progress > center_progress) ? MidAirfoilPath() :
                   RootAirfoilPath(),
        
        // Simplify path for preview mode using BOSL2 resample_path()
        simplified_path = $preview ? resample_path(base_path, n=30, keep_corners=10, closed=true) : base_path
    )
    simplified_path;

/**
 * Calculate the chord length at a specific wing position (unified interface)
 * @param z_location - Z position of this slice along the wing
 * @param wing_mode - Wing shape mode (1=trapezoidal, 2=elliptic)
 * @param wing_mm - Wing half-span length
 * @param root_chord_mm - Root chord length in mm
 * @param tip_chord_mm - Tip chord length in mm (for trapezoidal)
 * @param elliptic_pow - Elliptic distribution power factor (for elliptic)
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function WingSliceChordLength(z_location, wing_mode, wing_mm, root_chord_mm, tip_chord_mm=50, elliptic_pow=1.5) = 
    (wing_mode == 1) 
        ? ChordLengthTrapezoidal(z_location, root_chord_mm, tip_chord_mm)
        : ChordLengthElliptical(z_location, wing_mm, root_chord_mm, elliptic_pow);

/**
 * Returns a scaled and positioned airfoil path for a wing slice
 * @param z_location - Z position of this slice along the wing
 * @param wing_mode - Wing shape mode (1=trapezoidal, 2=elliptic)
 * @param wing_mm - Wing half-span length
 * @param root_chord_mm - Root chord length in mm
 * @param tip_chord_mm - Tip chord length in mm (for trapezoidal)
 * @param elliptic_pow - Elliptic distribution power factor (for elliptic)
 * @param center_line_perc - Percentage from leading edge for wing center line
 * @param washout_deg - Degrees of washout (0 = none)
 * @param washout_start - Where washout starts (mm from root)
 * @param washout_pivot_perc - Washout pivot point (percentage from LE)
 * @param tip_change_perc - Percentage where tip airfoil starts
 * @param center_change_perc - Percentage where center airfoil starts
 */
function WingSlicePath(z_location, wing_mode, wing_mm, root_chord_mm, tip_chord_mm=50, elliptic_pow=1.5, center_line_perc=90, washout_deg=0, washout_start=60, washout_pivot_perc=25, tip_change_perc=100, center_change_perc=100) = 
    let(
        // Calculate scale factor and chord length using helper functions
        current_chord_mm = WingSliceChordLength(z_location, wing_mode, wing_mm, root_chord_mm, tip_chord_mm, elliptic_pow),
        scale_factor = current_chord_mm / 100,
        
        // Get the base airfoil path
        base_path = GetAirfoilPath(z_location, wing_mm, tip_change_perc, center_change_perc),
        
        // Apply scaling and translation using BOSL2 transforms
        scaled_path = move([-center_line_perc / 100 * current_chord_mm, 0], 
                          p=scale([scale_factor, scale_factor], p=base_path)),
        
        // Apply washout rotation if needed
        final_path = (washout_deg > 0 && z_location > washout_start) ?
            ApplyWashoutToPath(scaled_path, z_location, current_chord_mm, wing_mode, washout_deg, washout_start, washout_pivot_perc, wing_mm) :
            scaled_path
    ) final_path;

/**
 * Applies washout rotation to an airfoil path
 * @param path - The 2D airfoil path to rotate
 * @param z_location - Current Z position along the wing
 * @param current_chord_mm - Chord length at this position
 * @param wing_mode - Wing shape mode (1=trapezoidal, 2=elliptic)
 * @param washout_deg - Degrees of washout (0 = none)
 * @param washout_start - Where washout starts (mm from root)
 * @param washout_pivot_perc - Washout pivot point (percentage from LE)
 * @param wing_mm - Wing half-span length
 */
function ApplyWashoutToPath(path, z_location, current_chord_mm, wing_mode, washout_deg, washout_start, washout_pivot_perc, wing_mm) =
    let(
        // Calculate washout parameters based on z position
        washout_span = wing_mm - washout_start,
        
        // Ensure we have a valid span and clamp progress to [0,1]
        washout_progress = (washout_span > 0) ? 
            max(0, min(1, (z_location - washout_start) / washout_span)) : 0,
        
        // Linear washout progression from start to tip
        // Negative for typical washout (nose down twist at tip)
        washout_deg_amount = -washout_progress * washout_deg,
        rotate_point = current_chord_mm * (washout_pivot_perc / 100),
        
        // Apply 2D rotation around the pivot point using BOSL2
        rotated_path = zrot(washout_deg_amount, p=path, cp=[rotate_point, 0])
    ) rotated_path;

/**
 * Calculate both anhedral angle and y-offset at a given wing position (simplified linear curve)
 * @param z_pos - Current position along the wing span (0 to wing_mm)
 * @param wing_mm - Total wing half-span length
 * @param anhedral_degrees - Maximum anhedral angle at wing tip
 * @param start_percentage - Where anhedral starts (percentage from root)
 * @return [angle, y_offset] - Array containing both angle and y-offset
 */
function AnhedralAtPosition(z_pos, wing_mm, anhedral_degrees, start_percentage) =
    let(
        // Convert z_pos to percentage of wing span
        z_pos_percentage = (wing_mm > 0) ? (z_pos / wing_mm) * 100 : 0,
        
        // Calculate progress from start percentage to tip (100%)
        progress = (z_pos_percentage <= start_percentage) ? 0 : 
                   (z_pos_percentage - start_percentage) / (100 - start_percentage),
        
        // Calculate the anhedral span in mm
        anhedral_span_mm = wing_mm * (100 - start_percentage) / 100,
        
        // For a given final angle, calculate the required y-offset at tip
        // tan(final_angle) = total_y_offset / anhedral_span
        // So total_y_offset = anhedral_span * tan(final_angle)
        total_y_offset_at_tip = anhedral_span_mm * tan(anhedral_degrees),
        
        // Current angle is the instantaneous slope angle at this position
        // For a smooth arc ending at final_angle, use quadratic progression
        angle = progress * progress * anhedral_degrees,
        
        // Y-offset follows the arc equation: y = (total_offset) * (3*t² - 2*t³)
        // This creates a smooth S-curve that starts with zero slope and ends at the correct angle
        smooth_progress = 3 * progress * progress - 2 * progress * progress * progress,
        y_offset = (progress <= 0) ? 0 : -total_y_offset_at_tip * smooth_progress
    ) [angle, y_offset];
    
/**
 * Parameterized wing creation module
 * Generates a complete wing using BOSL2 skin() function
 * @param wing_sections - Number of wing sections (more = higher resolution)
 * @param wing_mm - Wing half-span length in mm
 * @param root_chord_mm - Root chord length in mm
 * @param tip_chord_mm - Tip chord length in mm (for trapezoidal)
 * @param wing_mode - Wing shape mode (1=trapezoidal, 2=elliptic)
 * @param elliptic_pow - Elliptic distribution power factor (for elliptic)
 * @param center_line_perc - Percentage from leading edge for wing center line
 * @param washout_deg - Degrees of washout (0 = none)
 * @param washout_start - Where washout starts (mm from root)
 * @param washout_pivot_perc - Washout pivot point (percentage from LE)
 * @param anhedral_degrees - Maximum anhedral angle at wing tip
 * @param anhedral_start_perc - Where anhedral starts (percentage from root)
 * @param tip_change_perc - Percentage where tip airfoil starts
 * @param center_change_perc - Percentage where center airfoil starts
 */
/**
 * Create a wing from a configuration object
 * This is the new unified wing creation function that takes a wing configuration object
 * @param wing_config - Wing configuration object with all parameters
 */
module CreateWing(wing_config) {
    wing_section_mm = wing_config.wing_mm / wing_config.sections;

    bounds = get_current_split_bounds(wing_config.wing_mm);
    start_z = max(bounds[0], 0);
    end_z = min(bounds[1], wing_config.wing_mm);
            
    // Create a list of z positions that includes:
    // 1. Normal wing sections within the split bounds
    // 2. Exact split boundary positions (start_z and end_z)
    z_positions = [
                // Start boundary (if not at z=0)
                start_z,
                
                // Normal sections within bounds
                for (i = [0:wing_config.sections]) let(
                    z_pos = (wing_config.wing_mode == 1) ? 
                        wing_section_mm * i : 
                        QuadraticWingPosition(i, wing_config.sections, wing_config.wing_mm)
                ) if (z_pos > start_z && z_pos < end_z) z_pos,
                
                // End boundary (if not at tip)
                end_z
            ];
    
    // Debug output for split awareness
    if (is_split_mode()) {
        echo(str("CreateWing split-aware: generating ", len(z_positions), " sections for split ", 
                 $split_current_index, " z_bounds=[", $split_z_start, ",", $split_z_end, "]"));
        echo(str("Z positions: ", z_positions));
    }
    
    translate([wing_config.root_chord_mm * (wing_config.center_line_perc / 100), 0, 0]) {
        // Create wing profiles for the calculated z positions
        profiles = [
            for (j = [0:len(z_positions)-1]) let(
                z_pos = z_positions[j],
                
                // Calculate anhedral parameters for this position
                anhedral_data = AnhedralAtPosition(z_pos, wing_config.wing_mm, wing_config.anhedral.degrees, wing_config.anhedral.start_perc),
                anhedral_angle = anhedral_data[0],
                anhedral_y_offset = anhedral_data[1],
                
                // Get the base wing slice path (now purely z_position based)
                base_path = WingSlicePath(z_pos, wing_config.wing_mode, wing_config.wing_mm, wing_config.root_chord_mm, wing_config.tip_chord_mm, wing_config.elliptic_pow, wing_config.center_line_perc, wing_config.washout.degrees, wing_config.washout.start, wing_config.washout.pivot_perc, wing_config.airfoil.tip_change_perc, wing_config.airfoil.center_change_perc),
                
                // Create 3D path first
                path_3d = path3d(base_path, z_pos),
                
                // Apply anhedral rotation around x-axis (rotate the 3D airfoil section)
                rotated_path_3d = (anhedral_angle != 0) ? 
                    xrot(anhedral_angle, p=path_3d) : path_3d,
                
                // Apply anhedral y-offset using BOSL2 transform
                final_path = (anhedral_y_offset != 0) ?
                    move([0, anhedral_y_offset, 0], p=rotated_path_3d) : rotated_path_3d
            ) final_path
        ];
        
        // Create the wing surface using BOSL2 skin() function
        if (len(profiles) >= 2) {
            skin(profiles, slices=0, refine=1, method="direct", sampling="segment");
        } else if (len(profiles) == 1) {
            echo("Warning: Only one profile generated, creating minimal surface");
            skin([profiles[0], profiles[0]], slices=0, refine=1, method="direct", sampling="segment");
        }
    }
}
