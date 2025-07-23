/*
 * Wing Creator Module
 * Supports multiple airfoil sections with washout (twist) for stability.
 * 
 * Uses functional approach with path-based operations for efficiency.
 * Depends on BOSL2 library for advanced geometric operations.
 */

include <BOSL2/std.scad>

/**
 * Returns the appropriate airfoil path based on normalized wing position
 * @param nz - Normalized Z position (0 to 1) along the wing span
 * @param tip_change_nz - Percentage where tip airfoil starts (default: 100)
 * @param center_change_nz - Percentage where center airfoil starts (default: 100)
 */
function GetAirfoilPath(nz, tip_change_nz=100, center_change_nz=100) = 
    let(
        // Get base airfoil path
        base_path = (nz > tip_change_nz) ? TipAirfoilPath() :
                   (nz > center_change_nz) ? MidAirfoilPath() :
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
 * Applies washout rotation to an airfoil path
 * @param path - The 2D airfoil path to rotate
 * @param nz - Normalized Z position (0 to 1) along the wing span
 * @param washout_start_nz - Normalized washout start position (0 to 1)
 * @param current_chord_mm - Chord length at this position
 * @param washout_deg - Degrees of washout (0 = none)
 * @param washout_pivot_frac - Washout pivot point (fraction from LE)
 */
function ApplyWashoutToPath(path, nz, washout_start_nz, current_chord_mm, washout_deg, pivot_nx) =
    let(
        // Calculate washout parameters based on normalized position
        washout_span_nz = 1.0 - washout_start_nz,
        
        // Ensure we have a valid span and clamp progress to [0,1]
        washout_progress = (washout_span_nz > 0) ?
            max(0, min(1, (nz - washout_start_nz) / washout_span_nz)) : 0,

        // Linear washout progression from start to tip
        // Negative for typical washout (nose down twist at tip)
        washout_deg_amount = -washout_progress * washout_deg,
        rotate_point = current_chord_mm * pivot_nx,
        
        // Apply 2D rotation around the pivot point using BOSL2
        rotated_path = zrot(washout_deg_amount, p=path, cp=[rotate_point, 0])
    ) rotated_path;

/**
 * Calculate both anhedral angle and y-offset at a given normalized wing position
 * @param nz - Normalized Z position (0 to 1) along the wing span
 * @param anhedral_start_nz - Normalized anhedral start position (0 to 1)
 * @param wing_mm - Total wing half-span length (for y-offset calculation)
 * @param anhedral_degrees - Maximum anhedral angle at wing tip
 * @return object with angle and y_offset properties
 */
function AnhedralAtPosition(nz, anhedral_start_nz, wing_mm, anhedral_degrees) =
    let(
        // Calculate progress from start to tip (0 to 1)
        progress = (nz <= anhedral_start_nz) ? 0 : 
                   (nz - anhedral_start_nz) / (1.0 - anhedral_start_nz),
        
        // Calculate the anhedral span in mm
        anhedral_span_mm = wing_mm * (1.0 - anhedral_start_nz),
        
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
    ) object(
        angle = angle,
        y_offset = y_offset,
        progress = progress
    );
    
/**
 * Parameterized wing creation module
 * Generates a complete wing using BOSL2 skin() function
 * @param wing_sections - Number of wing sections (more = higher resolution)
 * @param wing_mm - Wing half-span length in mm
 * @param root_chord_mm - Root chord length in mm
 * @param tip_chord_mm - Tip chord length in mm (for trapezoidal)
 * @param wing_mode - Wing shape mode (1=trapezoidal, 2=elliptic)
 * @param elliptic_pow - Elliptic distribution power factor (for elliptic)
 * @param center_line_nx - Percentage from leading edge for wing center line
 * @param washout_deg - Degrees of washout (0 = none)
 * @param washout_start - Where washout starts (mm from root)
 * @param washout_pivot_perc - Washout pivot point (percentage from LE)
 * @param anhedral_degrees - Maximum anhedral angle at wing tip
 * @param anhedral_start_nz - Where anhedral starts (percentage from root)
 * @param tip_change_nz - Percentage where tip airfoil starts
 * @param center_change_nz - Percentage where center airfoil starts
 */
/**
 * Create a wing from a configuration object
 * This is the new unified wing creation function that takes a wing configuration object
 * @param wing_config - Wing configuration object with all parameters
 */
module CreateWing(wing_config) {
    wing_section_mm = wing_config.wing_mm / wing_config.sections;

    bounds = get_current_split_bounds(wing_config.wing_mm);
            
    // Create a list of z positions that includes:
    // 1. Normal wing sections within the split bounds
    // 2. Exact split boundary positions (start_z and end_z)
    z_positions = [
                // Start boundary (if not at z=0)
                bounds.start_z,
                
                // Normal sections within bounds
                for (i = [0:wing_config.sections]) let(
                    z_pos = (wing_config.wing_mode == 1) ? 
                        wing_section_mm * i : 
                        QuadraticWingPosition(i, wing_config.sections, wing_config.wing_mm)
                ) if (z_pos > bounds.start_z && z_pos < bounds.end_z) z_pos,
                
                // End boundary (if not at tip)
                bounds.end_z
            ];
    
    translate([wing_config.root_chord_mm * wing_config.center_line_nx, 0, 0]) {
        // Create wing profiles for the calculated z positions
        profiles = [
            for (z_pos = z_positions) let(
                // Calculate normalized position once for this z_pos
                nz = z_pos / wing_config.wing_mm,
                
                // Pre-calculate normalized start positions
                washout_start_nz = wing_config.washout.start_nz,
                anhedral_start_nz = wing_config.anhedral.start_nz,
                
                // Calculate anhedral parameters for this position
                anhedral = AnhedralAtPosition(nz, anhedral_start_nz, wing_config.wing_mm, wing_config.anhedral.degrees),

                // Calculate scale factor and chord length using helper functions
                current_chord_mm = WingSliceChordLength(z_pos, wing_config.wing_mode, wing_config.wing_mm, wing_config.root_chord_mm, wing_config.tip_chord_mm, wing_config.elliptic_pow),
                scale_factor = current_chord_mm / 100,
                
                // Get the base airfoil path (now using normalized z)
                base_path = GetAirfoilPath(nz, wing_config.airfoil.tip_change_nz, wing_config.airfoil.center_change_nz),
                
                // Apply scaling and translation using BOSL2 transforms
                scaled_path = move([-wing_config.center_line_nx * current_chord_mm, 0], 
                                p=scale([scale_factor, scale_factor], p=base_path)),
                
                // Apply washout rotation if needed (using normalized positions)
                washout_path = (wing_config.washout.degrees > 0 && nz > washout_start_nz) ?
                    ApplyWashoutToPath(scaled_path, nz, washout_start_nz, current_chord_mm, wing_config.washout.degrees, wing_config.washout.pivot_nx) :
                    scaled_path,

                // Create 3D path first
                path_3d = path3d(washout_path, z_pos),
                
                // Apply anhedral rotation around x-axis (rotate the 3D airfoil section)
                rotated_path_3d = (anhedral.angle != 0) ? 
                    xrot(anhedral.angle, p=path_3d) : path_3d,
                
                // Apply anhedral y-offset using BOSL2 transform
                final_path = (anhedral.y_offset != 0) ?
                    move([0, anhedral.y_offset, 0], p=rotated_path_3d) : rotated_path_3d
            ) final_path
        ];
        
        // Create the wing surface using BOSL2 skin() function
        skin(profiles, slices=0, refine=1, method="direct", sampling="segment");
    }
}
