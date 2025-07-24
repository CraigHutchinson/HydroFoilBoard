/*
 * Wing Creator Module
 * Supports multiple airfoil sections with washout (twist) for stability.
 * 
 * Uses functional approach with path-based operations for efficiency.
 * Depends on BOSL2 library for advanced geometric operations.
 * 
 * PERFORMANCE OPTIMIZATION:
 * - Airfoil paths are pre-computed at configuration time and stored in wing_config
 * - Both full-resolution and preview-optimized paths are cached
 * - Eliminates runtime path generation and resampling overhead
 * 
 * NEW: Connection Features for Multi-Part Printing
 * - Use CreateWing(wing_config, add_connections=true) for wings with male/female connectors
 * - Male connectors: Tapered extrusions added to wing ends (union operation)
 * - Female connectors: Tapered cavities subtracted from wing starts (difference operation)
 * - Configurable wall thickness (default 0.4mm) and connection length (default 4mm)
 * - Use CalculateWingZPositions() and CalculateWingSliceData() to access z positions and slice data
 */

include <BOSL2/std.scad>

/**
 * Returns the appropriate airfoil path based on normalized wing position
 * Uses pre-computed paths from wing configuration for optimal performance
 * @param nz - Normalized Z position (0 to 1) along the wing span
 * @param wing_config - Wing configuration object containing pre-computed paths
 */
function GetAirfoilPath(nz, wing_config) = 
    let(
        // Choose appropriate path based on position
        base_path = (nz > wing_config.airfoil.tip_change_nz) ? 
                      ($preview ? wing_config.airfoil.paths.tip_preview : wing_config.airfoil.paths.tip) :
                    (nz > wing_config.airfoil.center_change_nz) ? 
                      ($preview ? wing_config.airfoil.paths.mid_preview : wing_config.airfoil.paths.mid) :
                      ($preview ? wing_config.airfoil.paths.root_preview : wing_config.airfoil.paths.root)
    ) base_path;

/**
 * Calculate the chord length at a specific wing position
 * @param nz - Normalized Z position (0 to 1) along the wing span
 * @param chord_profile - Chord profile object containing wing geometry parameters
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function WingSliceChordLength(nz, chord_profile) = 
    (chord_profile.wing_mode == 1) 
        ? ChordLengthTrapezoidal(nz, chord_profile.root_chord_mm, chord_profile.tip_chord_mm)
        : ChordLengthElliptical(nz, chord_profile.root_chord_mm, chord_profile.elliptic_pow);

// Helper functions to access chord profile components
function get_wing_mode(wing_config) = wing_config.chord_profile.wing_mode;
function get_root_chord_mm(wing_config) = wing_config.chord_profile.root_chord_mm;
function get_tip_chord_mm(wing_config) = wing_config.chord_profile.tip_chord_mm;
function get_elliptic_pow(wing_config) = wing_config.chord_profile.elliptic_pow;

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
 * Calculate wing slice data for a given position
 * @param z_pos - Absolute Z position along wing span
 * @param wing_config - Wing configuration object
 * @return object with slice geometry data
 */
function CalculateWingSliceData(z_pos, wing_config) =
    let(
        // Calculate normalized position once for this z_pos
        nz = z_pos / wing_config.wing_mm,
        
        // Calculate chord length for this position using chord profile
        current_chord_mm = WingSliceChordLength(nz, wing_config.chord_profile),
        
        // Calculate anhedral parameters for this position
        anhedral = AnhedralAtPosition(nz, wing_config.anhedral.start_nz, wing_config.wing_mm, wing_config.anhedral.degrees),
        
        // Get the base airfoil path using pre-computed paths
        base_path = GetAirfoilPath(nz, wing_config)
    ) object(
        nz = nz,
        current_chord_mm = current_chord_mm,
        anhedral = anhedral,
        base_path = base_path
    );

/**
 * Apply all wing transforms to create final 3D profile
 * @param slice_data - Wing slice data from CalculateWingSliceData
 * @param wing_config - Wing configuration object
 * @return final 3D path ready for skinning
 */
function ApplyWingTransforms(slice_data, wing_config) =
    let(
        // Apply scaling and translation using BOSL2 transforms
        scaled_path = move([-wing_config.center_line_nx * slice_data.current_chord_mm, 0], 
                        p=scale([slice_data.current_chord_mm, slice_data.current_chord_mm] / 100, p=slice_data.base_path)),
        
        // Apply washout rotation if needed (using normalized positions)
        washout_path = (wing_config.washout.degrees > 0 && slice_data.nz > wing_config.washout.start_nz) ?
            ApplyWashoutToPath(scaled_path, slice_data.nz, wing_config.washout.start_nz, slice_data.current_chord_mm, wing_config.washout.degrees, wing_config.washout.pivot_nx) :
            scaled_path,

        // Create 3D path first
        path_3d = path3d(washout_path, slice_data.nz * wing_config.wing_mm),
        
        // Apply anhedral rotation around x-axis (rotate the 3D airfoil section)
        rotated_path_3d = (slice_data.anhedral.angle != 0) ? 
            xrot(slice_data.anhedral.angle, p=path_3d) : path_3d,
        
        // Apply anhedral y-offset using BOSL2 transform
        final_path = (slice_data.anhedral.y_offset != 0) ?
            move([0, slice_data.anhedral.y_offset, 0], p=rotated_path_3d) : rotated_path_3d
    ) final_path;

/**
 * Build a complete wing profile for a given Z position
 * This combines slice data calculation and transform application
 * @param z_pos - Absolute Z position along wing span
 * @param wing_config - Wing configuration object
 * @return final 3D path ready for skinning
 */
function BuildWingProfile(z_pos, wing_config) =
    let(
        slice_data = CalculateWingSliceData(z_pos, wing_config)
    ) ApplyWingTransforms(slice_data, wing_config);

/**
 * Generate z_positions array for wing sections
 * This function is exposed so connection features can use the same z_positions
 * @param wing_config - Wing configuration object
 * @return array of z positions for wing sections
 */
function CalculateWingZPositions(wing_config) =
    let(
        wing_section_mm = wing_config.wing_mm / wing_config.sections,
        bounds = get_current_split_bounds(wing_config.wing_mm)
    ) [
        // Start boundary (if not at z=0)
        bounds.start_z,
        
        // Normal sections within bounds
        for (i = [0:wing_config.sections]) let(
            z_pos = (get_wing_mode(wing_config) == 1) ? 
                wing_section_mm * i : 
                QuadraticWingPosition(i, wing_config.sections, wing_config.wing_mm)
        ) if (z_pos > bounds.start_z && z_pos < bounds.end_z) z_pos,
        
        // End boundary (if not at tip)
        bounds.end_z
    ];

/**
 * Create a tapered connector extrusion for male connections
 * @param base_path - The base airfoil path to extrude
 * @param connection_length - Length of the connector in mm
 * @param wall_thickness - Wall thickness for female side (male will be smaller by this amount)
 * @param z_start - Starting Z position for the extrusion
 * @param wing_config - Wing configuration for transforms
 * @param slice_data - Slice data at the connection point
 */
module CreateMaleConnector(base_path, connection_length, wall_thickness, z_start, wing_config, slice_data) {
    // Create tapered male connector that gets smaller towards the tip
    connector_profiles = [
        for (i = [0:4]) let(
            progress = i / 4,
            z_pos = z_start + progress * connection_length,
            // Taper from full size to (full size - wall_thickness * 2)
            scale_factor = 0.75, //1 - (progress * wall_thickness * 2 / slice_data.current_chord_mm),
            scaled_path = scale([scale_factor, scale_factor], p=base_path)
        ) ApplyWingTransforms(
            object(
                z_pos = z_pos,
                nz = z_pos / wing_config.wing_mm,
                current_chord_mm = slice_data.current_chord_mm,
                anhedral = slice_data.anhedral,
                base_path = scaled_path
            ), 
            wing_config
        )
    ];
    
    skin(connector_profiles, slices=0, refine=1, method="direct", sampling="segment");
}

/**
 * Create a tapered connector cavity for female connections
 * @param base_path - The base airfoil path to extrude
 * @param connection_length - Length of the connector in mm
 * @param wall_thickness - Wall thickness for female side
 * @param z_end - Ending Z position for the cavity
 * @param wing_config - Wing configuration for transforms
 * @param slice_data - Slice data at the connection point
 */
module CreateFemaleConnector(base_path, connection_length, wall_thickness, z_end, wing_config, slice_data) {
    // Create tapered female cavity that gets larger towards the inside
    connector_profiles = [
        for (i = [0:4]) let(
            progress = i / 4,
            z_pos = z_end - connection_length + progress * connection_length,
            // Taper from (full size + wall_thickness * 2) to full size
            scale_factor = 1 + ((1 - progress) * wall_thickness * 2 / slice_data.current_chord_mm),
            scaled_path = scale([scale_factor, scale_factor], p=base_path)
        ) ApplyWingTransforms(
            object(
                z_pos = z_pos,
                nz = z_end,
                current_chord_mm = slice_data.current_chord_mm,
                anhedral = slice_data.anhedral,
                base_path = scaled_path
            ), 
            wing_config
        )
    ];
    
    skin(connector_profiles, slices=0, refine=1, method="direct", sampling="segment");
}

/**
 * Get connection information for the current split section
 * Returns object with connection requirements for this section
 * @param wing_config - Wing configuration object
 * @return object with connection info (needs_start_female, needs_end_connection, etc.)
 */
function GetConnectionInfo(wing_config) =
    let(
        bounds = get_current_split_bounds(wing_config.wing_mm)
    ) object(
        needs_start_female = bounds.start_z > 0,
        needs_end_connection = bounds.end_z < wing_config.wing_mm,
        start_z = bounds.start_z,
        end_z = bounds.end_z,
        is_root_section = bounds.start_z == 0,
        is_tip_section = bounds.end_z == wing_config.wing_mm
    );

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
 * @param add_connections - Whether to add connection features for multi-part printing
 * @param connection_length - Length of connection taper in mm (default: 4mm)
 * @param wall_thickness - Wall thickness for connections in mm (default: 0.4mm)
 * @param is_male_end - Whether the end of this section should be male (true) or female (false)
 */
module CreateWing(wing_config, add_connections=false, connection_length=4, wall_thickness=0.4, is_male_end=true) {
    
    // Calculate z positions using the exposed function
    z_positions = CalculateWingZPositions(wing_config);
    bounds = get_current_split_bounds(wing_config.wing_mm);
    
    translate([get_root_chord_mm(wing_config) * wing_config.center_line_nx, 0, 0]) {
        
        // Always use union/difference structure, but make connectors conditional
        difference() {
            union() {
                // Main wing body
                main_wing_profiles = [
                    for (z_pos = z_positions) 
                        BuildWingProfile(z_pos, wing_config)
                ];
                skin(main_wing_profiles, slices=0, refine=1, method="direct", sampling="segment");
                
                // Add male connector at end if needed
                if (add_connections && bounds.end_z < wing_config.wing_mm && is_male_end) {
                    end_slice_data = CalculateWingSliceData(bounds.end_z, wing_config);
                    CreateMaleConnector(
                        end_slice_data.base_path, 
                        connection_length, 
                        wall_thickness, 
                        bounds.end_z, 
                        wing_config, 
                        end_slice_data
                    );
                }
            }
            
            // Subtract female connector at start if needed
            if (add_connections && bounds.start_z > 0) {
                start_slice_data = CalculateWingSliceData(bounds.start_z, wing_config);
                CreateFemaleConnector(
                    start_slice_data.base_path, 
                    connection_length, 
                    wall_thickness, 
                    bounds.start_z, 
                    wing_config, 
                    start_slice_data
                );
            }
        }
    }
}
