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
 * 
 * ANHEDRAL COMPENSATION:
 * - Wings with anhedral are automatically rotated to sit flat on print bed
 * - Rotation is calculated from bottom slice anhedral angle and applied to entire wing
 * - All internal structures (children) get the same rotation automatically
 * 
 * BOSL2-STYLE CHILDREN INTERFACE:
 * - CreateWing() accepts children for internal structures using BOSL2 diff() pattern
 * - CreateHollowWing() subtracts spar structures from inner cavity (leaves spars as solid material)
 * - Children are automatically rotated with anhedral compensation
 * - Use wing_internals() for structures to add (grid, ribs)
 * - Use wing_intersect() for structures that remain solid in hollow wing (subtracted from inner cavity)
 * - Use wing_remove() for features to subtract from wing (holes, voids)
 * - Use wing_spar_holes(array) for convenient spar hole addition
 * 
 * USAGE EXAMPLES:
 * CreateWing(wing_config) {
 *     wing_internals() { StructureGrid(...); }
 *     wing_spar_holes(spar_holes_array);
 *     wing_remove() { CustomVoid(); }
 * }
 * 
 * CreateHollowWing(wing_config, wall_thickness) {
 *     wing_intersect() { hollow_wing_spars(...); }  // Spars remain solid (subtracted from inner cavity)
 * }
 */

include <BOSL2/std.scad>


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
        airfoil = get_airfoil_at_nz(nz, wing_config.airfoil),
        
        // Calculate chord length for this position using chord profile
        chord_mm = WingSliceChordLength(nz, wing_config.chord_profile),
        
        // Calculate anhedral parameters for this position
        anhedral = AnhedralAtPosition(nz, wing_config.anhedral.start_nz, wing_config.wing_mm, wing_config.anhedral.degrees),
        
        // Get the base airfoil path using pre-computed paths in preview and per-slice thickness in render
        scaled_path = get_airfoil_path( airfoil, chord_mm)
    ) object(
        z = z_pos,
        nz = nz,
        airfoil = airfoil,
        chord_mm = chord_mm,
        anhedral = anhedral,
        scaled_path = scaled_path
    );

/**
 * Apply all wing transforms to create final 3D profile
 * @param slice_data - Wing slice data from CalculateWingSliceData
 * @param wing_config - Wing configuration object
 * @return final 3D path ready for skinning
 */
function ApplyWingTransforms( scaled_path, slice_data, wing_config) =
    let(
        // If no data, return empty list
        washout_path = 
            (wing_config.washout.degrees > 0 && slice_data.nz > wing_config.washout.start_nz) ?
                ApplyWashoutToPath(scaled_path, slice_data.nz, wing_config.washout.start_nz, slice_data.chord_mm, wing_config.washout.degrees, wing_config.washout.pivot_nx)
                : scaled_path,
        path_3d = path3d(washout_path, 0),
        rotated_path_3d = (slice_data.anhedral.angle != 0) ? xrot(slice_data.anhedral.angle, p=path_3d ) : path_3d,
        final_path = move([
            wing_config.center_line_nx * (wing_config.chord_profile.root_chord_mm - slice_data.chord_mm),
            slice_data.anhedral.y_offset,
            slice_data.nz * wing_config.wing_mm
        ], p=rotated_path_3d)
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
    ) ApplyWingTransforms(slice_data.scaled_path, slice_data, wing_config);

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
            scale_factor = 0.75, //1 - (progress * wall_thickness * 2 / slice_data.chord_mm),
            scaled_path = scale([scale_factor, scale_factor], p=base_path)
        ) ApplyWingTransforms(
            object(
                z_pos = z_pos,
                nz = z_pos / wing_config.wing_mm,
                current_chord_mm = slice_data.chord_mm,
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
            scale_factor = 1 + ((1 - progress) * wall_thickness * 2 / slice_data.chord_mm),
            scaled_path = scale([scale_factor, scale_factor], p=base_path)
        ) ApplyWingTransforms(
            object(
                z_pos = z_pos,
                nz = z_end,
                current_chord_mm = slice_data.chord_mm,
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
                
        
        // Y-offset follows the arc equation: y = (total_offset) * (3*t² - 2*t³)
        // This creates a smooth S-curve that starts with zero slope and ends at the correct angle
        smooth_progress = 3 * progress * progress - 2 * progress * progress * progress,
        y_offset = (progress <= 0) ? 0 : -total_y_offset_at_tip * smooth_progress,

        // Current angle is the instantaneous slope angle at this position
        //TODO; 4 is arbitrary as to keep the split section upright for printing a wing with default values
        angle = progress * anhedral_degrees * 4,
    ) object(
        angle = angle,
        y_offset = y_offset,
        progress = progress
    );
 
/**
 * Create a hollow wing with additive spar structure
 * This creates a wing shell and adds spar structures as positive geometry for better 3D printing
 * @param wing_config - Wing configuration object with all parameters
 * @param wall_thickness - Wing shell thickness in mm (default: 1.2mm)
 * @param add_connections - Whether to add connection features for multi-part printing
 * @param connection_length - Length of connection taper in mm (default: 4mm)
 * @param connection_wall_thickness - Wall thickness for connections in mm (default: 0.4mm)
 * @param is_male_end - Whether the end of this section should be male (true) or female (false)
 */
module CreateHollowWing(wing_config, wall_thickness=1.2, add_connections=false, connection_length=4, connection_wall_thickness=0.4, is_male_end=true) {
    
    // Calculate z positions using the exposed function
    z_positions = CalculateWingZPositions(wing_config);
    start_z = z_positions[0];
    end_z = z_positions[len(z_positions)-1];
 
    wing_slices = [
        for (z_pos = z_positions) 
            CalculateWingSliceData(z_pos, wing_config)
    ];

    // Place on cut face
    //  - anhedral compensation rotation to make wing sit flat on print bed
   place_on_face_xrot = wing_slices[0].anhedral.angle;
    
    // Apply compensation rotation around x-axis to make wing sit flat
    xrot(-place_on_face_xrot, cp = [0,0,start_z]) {

        // Create outer wing profiles (normal airfoil)
        outer_profiles = [
            for (slice_data = wing_slices) 
               ApplyWingTransforms(slice_data.scaled_path, slice_data, wing_config)
        ];
        
        // Create inner wing profiles (offset inward by wall thickness)
        // Stop hollow cavity wall_thickness distance from wing tip for solid tip structure
        hollow_end_z = wing_config.wing_mm - wall_thickness;
        
        inner_profiles = [            
            for (slice_data = wing_slices) 
                let(
                    // Calculate actual airfoil thickness at this chord length
                    max_thickness_mm = slice_data.chord_mm * slice_data.airfoil.max_thickness_normalized,
                                
                    // If chord thickness is deep enough for a hollow core
                    is_hollow_slice = slice_data.z < hollow_end_z 
                        && max_thickness_mm > (wall_thickness*3),
                 ) 
        // Filter out empty paths that occur when chord is too small for offset
                if ( is_hollow_slice ) 
                    let(
                        offset_path = offset(slice_data.scaled_path, r=-wall_thickness, closed=true )
                    )
                    if ( is_list(offset_path) && len(offset_path) > 0 )
                        ApplyWingTransforms( offset_path, slice_data, wing_config)
        ];
        
        // Use BOSL2-style diff() pattern for boolean operations
        diff("wing_remove", "wing_keep") {
            // Main wing shell - create as difference of outer and inner skins
            if (len(inner_profiles) > 1) {
                // Create the basic hollow wing shell
                difference() {
                    skin(outer_profiles, slices=0, refine=1, method="direct", sampling="segment");
                    // The inner cavity will have spar structures subtracted from it
                    diff("spar_remove", "spar_keep") {
                        skin(inner_profiles, slices=0, refine=1, method="direct", sampling="segment");
                        // Subtract spar structures from inner cavity - this leaves spar material as solid
                        tag("spar_remove") children();
                    }
                }
            } else {
                // Fallback to solid wing if no valid inner profiles
                skin(outer_profiles, slices=0, refine=1, method="direct", sampling="segment");
            }
            
            // Add unconstrained positive geometry (connectors, etc.)
            tag("wing_keep") union() {}
            
            // Add male connector at end if needed
            if (add_connections && end_z < wing_config.wing_mm && is_male_end) {
                tag("wing_keep") {
                    end_slice_data = CalculateWingSliceData(end_z, wing_config);
                    CreateMaleConnector(
                        end_slice_data.base_path, 
                        connection_length, 
                        connection_wall_thickness, 
                        end_z, 
                        wing_config, 
                        end_slice_data
                    );
                }
            }
            
            // Subtract female connector at start if needed
            if (add_connections && start_z > 0) {
                tag("wing_remove") {
                    start_slice_data = CalculateWingSliceData(start_z, wing_config);
                    CreateFemaleConnector(
                        start_slice_data.base_path, 
                        connection_length, 
                        connection_wall_thickness, 
                        start_z, 
                        wing_config, 
                        start_slice_data
                    );
                }
            }
        }
    }
}

/**
 * Build a hollow wing profile (offset inward) for a given Z position
 * This creates the inner cavity profile for hollow wing construction
 * @param z_pos - Absolute Z position along wing span
 * @param wing_config - Wing configuration object
 * @param wall_thickness - Inward offset distance for the cavity
 * @return final 3D path for inner cavity
 */
function BuildHollowWingProfile(z_pos, wing_config, wall_thickness) =
    let(
        // Calculate slice data normally
        slice_data = CalculateWingSliceData(z_pos, wing_config),
        
        // Get offset airfoil path (negative wall_thickness for inward offset)
        offset_path = get_offset_airfoil_path(
            get_airfoil_at_nz(slice_data.nz, wing_config.airfoil), 
            slice_data.chord_mm, 
            -wall_thickness
        ),
        
        // Create modified slice data with offset path
        hollow_slice_data = object(
            nz = slice_data.nz,
            current_chord_mm = slice_data.chord_mm,
            anhedral = slice_data.anhedral,
            scaled_path = offset_path
        )
    ) ApplyWingTransforms(hollow_slice_data, wing_config);

/**
 * Create positive spar tube structures for hollow wings with integrated holes and grid
 * Use this as a child of CreateHollowWing to add solid spar tube geometry with proper holes
 * This creates individual spar tubes (cylinders), grid structure, and subtracts the actual spar holes
 */
module hollow_wing_spars(spar_config, wing_config) {
    difference() {
        union() {
            // Add the grid structure (ribs and cross-members) as positive geometry
            StructureSparGridConfigured(wing_config, spar_config);
            
            // Create individual spar tubes with smooth transitions to structural bars
            // Generate spar holes and use their position data to create enhanced tubes
            spar_holes = generate_spar_holes(spar_config, wing_config);
            for (spar = spar_holes) {
                CreateSparTubeWithTransition(spar, wing_config);
            }
        }
        
        // Subtract all spar holes from the combined structure using existing function
        for (spar = generate_spar_holes(spar_config, wing_config)) {
            CreateSparHole(spar);
        }
    }
}

module CreateWing(wing_config, add_connections=false, connection_length=4, wall_thickness=0.4, is_male_end=true) {
    
    // Calculate z positions using the exposed function
    z_positions = CalculateWingZPositions(wing_config);
    bounds = get_current_split_bounds(wing_config.wing_mm);
    
    // Calculate anhedral compensation rotation to make wing sit flat on print bed
    // Use the bottom slice (start of bounds or z=0) to determine the rotation needed
    bottom_slice = CalculateWingSliceData(bounds.start_z, wing_config);

    // Apply compensation rotation around x-axis to make wing sit flat
    // This rotation is applied to both the wing body AND any children (internal structures)
    xrot(-bottom_slice.anhedral.angle, cp = [0,0,bounds.start_z]) {

       wing_profiles = [
            for (z_pos = z_positions) 
                BuildWingProfile(z_pos, wing_config)
        ];

        // Use BOSL2-style diff() pattern to allow children to participate in boolean operations
        diff("wing_remove", "wing_keep") {
            // Main wing body - base object (translated for center line positioning)
            skin(wing_profiles, slices=0, refine=1, method="direct", sampling="segment");
            
            // Add male connector at end if needed
            if (add_connections && bounds.end_z < wing_config.wing_mm && is_male_end) {
                tag("wing_keep") {
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
                tag("wing_remove") {
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
            
            // Children can add internal structures and tag them as "wing_keep" or "wing_remove"
            children();
        }
    }
}

/**
 * Helper modules for BOSL2-style wing internal structure
 * These provide clean syntax for adding internal structures to wings
 */

/**
 * Add internal structures to wing (grid, ribs, etc.)
 * Use this as a child of CreateWing to add structures that will be kept
 */
module wing_internals() {
    tag("wing_keep") children();
}

/**
 * Add structures to hollow wing that remain as solid material (spars, reinforcements, etc.)
 * Use this as a child of CreateHollowWing to subtract structures from the inner cavity
 * This leaves the spar structures as solid material in the final wing
 */
module wing_intersect() {
    tag("spar_remove") children();
}

/**
 * Remove features from wing (holes, voids, etc.)  
 * Use this as a child of CreateWing to subtract features from the wing
 */
module wing_remove() {
    tag("wing_remove") children();
}

/**
 * Add spar holes to wing using configuration array
 * Convenience module that applies wing_remove tag automatically
 */
module wing_spar_holes(spar_holes_array) {
    tag("wing_remove") {
        for (spar = spar_holes_array) {
            CreateSparHole(spar);
        }
    }
}
