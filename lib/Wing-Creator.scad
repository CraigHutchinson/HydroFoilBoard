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
 * @param index - Current slice index along the wing span
 * @param wing_sections - Total number of sections in the wing
 */
function GetAirfoilPath(index, wing_sections) = 
    let(
        tip_airfoil_change_index = wing_sections * (tip_airfoil_change_perc / 100),
        center_airfoil_change_index = wing_sections * (center_airfoil_change_perc / 100),
        
        // Get base airfoil path
        base_path = (index > tip_airfoil_change_index) ? TipAirfoilPath() :
                   (index > center_airfoil_change_index) ? MidAirfoilPath() :
                   RootAirfoilPath(),
        
        // Simplify path for preview mode using BOSL2 resample_path()
        simplified_path = $preview ? resample_path(base_path, n=50, closed=true) : base_path
    )
    simplified_path;

/**
 * Calculate the chord length at a specific wing position using index (wing_mode == 1)
 * @param index - Current slice index along the wing span
 * @param wing_sections - Total number of sections in the wing
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function WingSliceChordLengthByIndex(index, wing_sections) = 
    ChordLengthAtIndex(index, wing_sections);

/**
 * Calculate the chord length at a specific wing position using z_location (wing_mode > 1)
 * @param z_location - Z position of this slice along the wing
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function WingSliceChordLengthByPosition(z_location) = 
    ChordLengthAtEllipsePosition((wing_mm + 0.1), wing_root_chord_mm, z_location);

/**
 * Calculate the chord length at a specific wing position (unified interface)
 * @param index - Current slice index along the wing span
 * @param z_location - Z position of this slice along the wing
 * @param wing_sections - Total number of sections in the wing
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function WingSliceChordLength(index, z_location, wing_sections) = 
    (wing_mode == 1) 
        ? WingSliceChordLengthByIndex(index, wing_sections)
        : WingSliceChordLengthByPosition(z_location);

/**
 * Calculate the scale factor for a wing slice using index (wing_mode == 1)
 * @param index - Current slice index along the wing span
 * @param wing_sections - Total number of sections in the wing
 * @return scale_factor - Scaling factor relative to 100mm base chord
 */
function WingSliceScaleFactorByIndex(index, wing_sections) = 
    WingSliceChordLengthByIndex(index, wing_sections) / 100;

/**
 * Calculate the scale factor for a wing slice using z_location (wing_mode > 1)
 * @param z_location - Z position of this slice along the wing
 * @return scale_factor - Scaling factor relative to 100mm base chord
 */
function WingSliceScaleFactorByPosition(z_location) = 
    WingSliceChordLengthByPosition(z_location) / 100;

/**
 * Calculate the scale factor for a wing slice (unified interface)
 * @param index - Current slice index along the wing span
 * @param z_location - Z position of this slice along the wing
 * @param wing_sections - Total number of sections in the wing
 * @return scale_factor - Scaling factor relative to 100mm base chord
 */
function WingSliceScaleFactor(index, z_location, wing_sections) = 
    (wing_mode == 1) 
        ? WingSliceScaleFactorByIndex(index, wing_sections)
        : WingSliceScaleFactorByPosition(z_location);

/**
 * Returns a scaled and positioned airfoil path for a wing slice
 * @param index - Current slice index along the wing span
 * @param z_location - Z position of this slice along the wing
 * @param wing_sections - Total number of sections in the wing
 */
function WingSlicePath(index, z_location, wing_sections) = 
    let(
        // Calculate scale factor and chord length using helper functions
        scale_factor = WingSliceScaleFactor(index, z_location, wing_sections),
        current_chord_mm = WingSliceChordLength(index, z_location, wing_sections),
        
        // Get the base airfoil path
        base_path = GetAirfoilPath(index, wing_sections),
        
        // Apply scaling and translation using BOSL2 transforms
        scaled_path = move([-wing_center_line_perc / 100 * current_chord_mm, 0], 
                          p=scale([scale_factor, scale_factor], p=base_path)),
        
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
 * Main wing creation module
 * Generates the complete wing using BOSL2 skin() function
 */
module CreateWing() {
    wing_section_mm = wing_mm / wing_sections;
    
    translate([wing_root_chord_mm * (wing_center_line_perc / 100), 0, 0]) {
        // Create wing profiles for each section
        profiles = [
            for (i = [0:wing_sections]) let(
                z_pos = (wing_mode == 1) ? wing_section_mm * i : f(i, wing_sections, wing_mm),
                
                // Calculate anhedral parameters for this position
                anhedral_data = AnhedralAtPosition(z_pos, wing_mm, Wing_Anhedral_Degrees, 
                                                 Wing_Anhedral_Start_At_Percentage),
                anhedral_angle = anhedral_data[0],
                anhedral_y_offset = anhedral_data[1],
                
                // Get the base wing slice path
                base_path = WingSlicePath(i, z_pos, wing_sections),
                
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
        skin(profiles, slices=0, refine=1, method="direct", sampling="segment");
    }
}