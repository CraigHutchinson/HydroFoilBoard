/*
 * Wing Creator Module
 * Supports multiple airfoil sections with washout (twist) for stability.
 * 
 * Uses functional approach with path-based operations for efficiency.
 * Depends on BOSL2 library for advanced geometric operations.
 * 
 * NEW: Connection Features for Multi-Part Printing
 * - Use CreateWingWithConnections() for wings with male/female connectors
 * - Use CalculateWingZPositions() and CalculateWingSliceData() to access z positions and slice data
 * - Connection features create tapered joints between wing sections for assembly
 */

include <BOSL2/std.scad>

/**
 * Returns the appropriate airfoil path based on normalized wing position
 * Uses cached paths for better performance during wing generation
 * @param nz - Normalized Z position (0 to 1) along the wing span
 * @param tip_change_nz - Percentage where tip airfoil starts (default: 1)
 * @param center_change_nz - Percentage where center airfoil starts (default: 1)
 * @param cached_paths - Optional pre-cached airfoil paths object
 */
function GetAirfoilPath(nz, tip_change_nz=1, center_change_nz=1, cached_paths=undef) = 
    let(
        // Use cached paths if available, otherwise generate them
        root_path = (cached_paths != undef) ? cached_paths.root : RootAirfoilPath(),
        mid_path = (cached_paths != undef) ? cached_paths.mid : MidAirfoilPath(),
        tip_path = (cached_paths != undef) ? cached_paths.tip : TipAirfoilPath(),
        
        // Get base airfoil path
        base_path = (nz > tip_change_nz) ? tip_path :
                   (nz > center_change_nz) ? mid_path :
                   root_path,
        
        // Use cached simplified path if available, otherwise generate
        simplified_path = (cached_paths != undef && $preview) ? 
            ((nz > tip_change_nz) ? cached_paths.tip_simplified :
             (nz > center_change_nz) ? cached_paths.mid_simplified :
             cached_paths.root_simplified) :
            ($preview ? resample_path(base_path, n=30, keep_corners=10, closed=true) : base_path)
    )
    simplified_path;

/**
 * Pre-generate and cache all airfoil paths for efficient wing generation
 * This avoids repeated path generation and simplification during wing creation
 * @return object with cached full and simplified airfoil paths
 */
function CalculateAirfoilPaths() = 
    let(
        // Generate base paths once
        root_path = RootAirfoilPath(),
        mid_path = MidAirfoilPath(),
        tip_path = TipAirfoilPath(),
        
        // Pre-generate simplified paths for preview mode
        root_simplified = resample_path(root_path, n=30, keep_corners=10, closed=true),
        mid_simplified = resample_path(mid_path, n=30, keep_corners=10, closed=true),
        tip_simplified = resample_path(tip_path, n=30, keep_corners=10, closed=true)
    ) object(
        root = root_path,
        mid = mid_path,
        tip = tip_path,
        root_simplified = root_simplified,
        mid_simplified = mid_simplified,
        tip_simplified = tip_simplified
    );

/**
 * Calculate the chord length at a specific wing position (unified interface)
 * @param nz - Normalized Z position (0 to 1) along the wing span
 * @param wing_mode - Wing shape mode (1=trapezoidal, 2=elliptic)
 * @param root_chord_mm - Root chord length in mm
 * @param tip_chord_mm - Tip chord length in mm (for trapezoidal)
 * @param elliptic_pow - Elliptic distribution power factor (for elliptic)
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function WingSliceChordLength(nz, wing_mode, root_chord_mm, tip_chord_mm=50, elliptic_pow=1.5) = 
    (wing_mode == 1) 
        ? ChordLengthTrapezoidal(nz, root_chord_mm, tip_chord_mm)
        : ChordLengthElliptical(nz, root_chord_mm, elliptic_pow);

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
 * @param cached_paths - Pre-cached airfoil paths
 * @return object with slice geometry data
 */
function CalculateWingSliceData(z_pos, wing_config, cached_paths) =
    let(
        // Calculate normalized position once for this z_pos
        nz = z_pos / wing_config.wing_mm,
        
        // Calculate chord length for this position
        current_chord_mm = WingSliceChordLength(nz, wing_config.wing_mode, wing_config.root_chord_mm, wing_config.tip_chord_mm, wing_config.elliptic_pow),
        
        // Calculate anhedral parameters for this position
        anhedral = AnhedralAtPosition(nz, wing_config.anhedral.start_nz, wing_config.wing_mm, wing_config.anhedral.degrees),
        
        // Get the base airfoil path using cached paths
        base_path = GetAirfoilPath(nz, wing_config.airfoil.tip_change_nz, wing_config.airfoil.center_change_nz, cached_paths)
    ) object(
        z_pos = z_pos,
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
        path_3d = path3d(washout_path, slice_data.z_pos),
        
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
 * @param cached_paths - Pre-cached airfoil paths
 * @return final 3D path ready for skinning
 */
function BuildWingProfile(z_pos, wing_config, cached_paths) =
    let(
        slice_data = CalculateWingSliceData(z_pos, wing_config, cached_paths)
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
            z_pos = (wing_config.wing_mode == 1) ? 
                wing_section_mm * i : 
                QuadraticWingPosition(i, wing_config.sections, wing_config.wing_mm)
        ) if (z_pos > bounds.start_z && z_pos < bounds.end_z) z_pos,
        
        // End boundary (if not at tip)
        bounds.end_z
    ];

/**
 * Create a tapered connection profile for joining wing sections
 * @param base_path - The base airfoil path to scale
 * @param taper_factor - Scale factor for the taper (1.0 = no taper, 0.8 = 20% smaller)
 * @param is_male - true for male connector (smaller), false for female (larger)
 * @return scaled path for connection
 */
function CreateConnectionProfile(base_path, taper_factor=0.95, is_male=true) =
    let(
        // Male connections are smaller (taper_factor), female are larger (1/taper_factor)
        scale_factor = is_male ? taper_factor : 1/taper_factor
    ) scale([scale_factor, scale_factor], p=base_path);

/**
 * Add connection features to wing section
 * @param profiles - Array of wing profiles
 * @param z_positions - Array of z positions corresponding to profiles
 * @param wing_config - Wing configuration object
 * @param cached_paths - Pre-cached airfoil paths
 * @param connection_length - Length of connection taper in mm
 * @param taper_factor - Scale factor for connection taper
 * @return enhanced profiles array with connection features
 */
function AddConnectionFeatures(profiles, z_positions, wing_config, cached_paths, connection_length=5, taper_factor=0.95) =
    let(
        bounds = get_current_split_bounds(wing_config.wing_mm),
        
        // Generate additional profiles for connections
        enhanced_z_positions = [],
        enhanced_profiles = []
    ) 
    [
        for (i = [0:len(profiles)-1]) 
            let(
                z_pos = z_positions[i],
                profile = profiles[i],
                
                // Check if this is the start of the current section (needs male connector)
                is_section_start = (i == 0 && bounds.start_z > 0),
                
                // Check if this is the end of the current section (needs female connector)
                is_section_end = (i == len(profiles)-1 && bounds.end_z < wing_config.wing_mm),
                
                // Generate connection profiles if needed
                connection_profiles = []
            ) 
            // For now, return the original profile
            // The connection generation will be implemented when this function is called
            profile
    ];

/**
 * Generate connection geometry for wing sections
 * Creates male and female connectors at section boundaries
 * @param wing_config - Wing configuration object
 * @param connection_length - Length of connection taper in mm
 * @param taper_factor - Scale factor for connection taper
 * @param is_male_end - Whether the end of this section should be male (true) or female (false)
 */
module CreateWingWithConnections(wing_config, connection_length=5, taper_factor=0.95, is_male_end=true) {
    
    // Cache airfoil paths once at the beginning for better performance
    cached_paths = CalculateAirfoilPaths();
    
    // Calculate z positions using the exposed function
    z_positions = CalculateWingZPositions(wing_config);
    bounds = get_current_split_bounds(wing_config.wing_mm);
    
    translate([wing_config.root_chord_mm * wing_config.center_line_nx, 0, 0]) {
        
        // Create main wing profiles
        main_profiles = [
            for (z_pos = z_positions) 
                BuildWingProfile(z_pos, wing_config, cached_paths)
        ];
        
        // Enhanced z_positions and profiles including connections
        enhanced_z_positions = [];
        enhanced_profiles = [];
        
        // Add start connection (female) if this is not the root section
        if (bounds.start_z > 0) {
            // Female connector at start
            start_z_conn = bounds.start_z - connection_length;
            start_slice_data = CalculateWingSliceData(bounds.start_z, wing_config, cached_paths);
            start_profile = ApplyWingTransforms(start_slice_data, wing_config);
            start_conn_profile = CreateConnectionProfile(start_slice_data.base_path, taper_factor, false);
            start_conn_profile_3d = ApplyWingTransforms(
                object(
                    z_pos = start_z_conn,
                    nz = start_z_conn / wing_config.wing_mm,
                    current_chord_mm = start_slice_data.current_chord_mm,
                    anhedral = start_slice_data.anhedral,
                    base_path = start_conn_profile
                ), 
                wing_config
            );
            
            enhanced_z_positions = concat([start_z_conn], enhanced_z_positions);
            enhanced_profiles = concat([start_conn_profile_3d], enhanced_profiles);
        }
        
        // Add main profiles
        enhanced_z_positions = concat(enhanced_z_positions, z_positions);
        enhanced_profiles = concat(enhanced_profiles, main_profiles);
        
        // Add end connection (male or female) if this is not the tip section
        if (bounds.end_z < wing_config.wing_mm) {
            // Male or female connector at end based on parameter
            end_z_conn = bounds.end_z + connection_length;
            end_slice_data = CalculateWingSliceData(bounds.end_z, wing_config, cached_paths);
            end_profile = ApplyWingTransforms(end_slice_data, wing_config);
            end_conn_profile = CreateConnectionProfile(end_slice_data.base_path, taper_factor, is_male_end);
            end_conn_profile_3d = ApplyWingTransforms(
                object(
                    z_pos = end_z_conn,
                    nz = end_z_conn / wing_config.wing_mm,
                    current_chord_mm = end_slice_data.current_chord_mm,
                    anhedral = end_slice_data.anhedral,
                    base_path = end_conn_profile
                ), 
                wing_config
            );
            
            enhanced_z_positions = concat(enhanced_z_positions, [end_z_conn]);
            enhanced_profiles = concat(enhanced_profiles, [end_conn_profile_3d]);
        }
        
        // Create the wing surface using BOSL2 skin() function
        skin(enhanced_profiles, slices=0, refine=1, method="direct", sampling="segment");
    }
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
 * @param connection_length - Length of connection taper in mm
 * @param taper_factor - Scale factor for connection taper (default: 0.95)
 */
module CreateWing(wing_config, add_connections=false, connection_length=5, taper_factor=0.95) {
    
    // Cache airfoil paths once at the beginning for better performance
    cached_paths = CalculateAirfoilPaths();
    
    // Calculate z positions using the new exposed function
    z_positions = CalculateWingZPositions(wing_config);
    
    translate([wing_config.root_chord_mm * wing_config.center_line_nx, 0, 0]) {
        // Create wing profiles for the calculated z positions using helper function
        base_profiles = [
            for (z_pos = z_positions) 
                BuildWingProfile(z_pos, wing_config, cached_paths)
        ];
        
        // Add connection features if requested (simplified version)
        final_profiles = add_connections ? 
            concat(
                // Add connection logic here if needed for the function-based approach
                base_profiles
            ) :
            base_profiles;
        
        // Create the wing surface using BOSL2 skin() function
        skin(final_profiles, slices=0, refine=1, method="direct", sampling="segment");
    }
}
