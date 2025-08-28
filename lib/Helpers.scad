
// EaseInOut cubic function from t in [0,1] to eased progress [0,1]
function easeInOutCubic(t) = 
    t < 0.5? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;

// Function to calculate the rib cord length along an elliptical path
//	a: The semi-major axis of the ellipse (half the total span of the wing).
//	b: The semi-minor axis (maximum chord length, usually at the root).
//	x: The distance from the center (root) along the span.
/**
 * Calculate wing position using quadratic curve distribution
 * Creates a quadratic curve that decreases towards the highest part of the wing
 * @param section_index - Current section index (0 to numSections)
 * @param total_sections - Total number of wing sections
 * @param wing_span_mm - Total wing span in millimeters
 * @return position_mm - Position along wing span in millimeters
 */
function QuadraticWingPosition(section_index, total_sections, wing_span_mm) = 
    wing_span_mm * (1 - pow((total_sections - section_index) / total_sections, 2));

// Get the starting point of the washout
function WashoutStart(count, max, wash_st, wing_mm) = (count >= max || QuadraticWingPosition(count, max, wing_mm) > wash_st)
                                                          ? count
                                                          : WashoutStart(count + 1, max, wash_st, wing_mm);

// Find the aproximate airfoil hight a given distance from the TE
function AirfoilHeightAtPosition(path, distance, tolerance = 0.5) =
    let(points_within_tolerance = [for (pt = path) if (abs(pt[0] - distance) <= tolerance)
            pt], // Selecting points within the given tolerance
        max_y = max([for (pt = points_within_tolerance) pt[1]]),
        min_y = min([for (pt = points_within_tolerance) pt[1]]))
        abs(max_y - min_y); // Return the difference in y values of the top and bottom points

// Global variables to track split print context
$split_print_mode = false;
$split_print_config = undef;
$split_current_index = undef;
$split_z_start = undef;
$split_z_end = undef;

/**
 * Split print module - similar to BOSL2's diff() but for print splitting
 * This creates a context where child modules can be automatically split for printing
 * Usage: split_print(wing_config.print) main_wing();
 */
module split_print(print_config) {
    // Set global context variables for child modules to access
    $split_print_mode = (print_config.splits > 1);
    $split_print_config = print_config;
    
    // Apply the splitting to all children
    split_wing_into_parts_aware(print_config) children();

    // Reference implementation
    //#split_wing_into_parts(print_config) children();
}

/**
 * Enhanced split function that provides context awareness to children
 * This version sets additional context variables so children can optimize their rendering
 */
module split_wing_into_parts_aware(print_config, print_height_mm=0) {
    
    // Calculate part spacing using the global af_bbox (available when this function runs)
    part_spacing = af_bbox.w - af_bbox.z + (print_config.build_area.x / print_config.splits);
    
    // If print_height_mm > 0, only print up to that height from the bottom of each part
    part_height = (print_height_mm > 0 && print_height_mm < print_config.splits_length) ? 
        print_height_mm : print_config.splits_length;

    for (i = [0:print_config.splits-1]) {
        // Set split context for children to access
        $split_current_index = i;
        $split_z_start = i * print_config.splits_length;
        $split_z_end = (i + 1) * print_config.splits_length;
        
        fwd(i * part_spacing) down($split_z_start) children();
    }
}

// Function to split a module into printable parts using wing configuration
// Uses the precalculated print configuration from wing_config.print
module split_wing_into_parts(print_config, print_height_mm=0) {
    
    // Calculate part spacing using the global af_bbox (available when this function runs)
    part_spacing = af_bbox.w - af_bbox.z + (print_config.build_area.x / print_config.splits);
    
    // If print_height_mm > 0, only print up to that height from the bottom of each part
    part_height = (print_height_mm > 0 && print_height_mm < print_config.splits_length) ? 
        print_height_mm : print_config.splits_length;

    for (i = [0:print_config.splits-1]) {
        fwd(i * part_spacing) intersection() {
            down(i * print_config.splits_length) children();
            cube([print_config.build_area.x, print_config.build_area.y, part_height], anchor=BOTTOM+LEFT);
        }
    }
}

/**
 * Helper functions for split-aware rendering
 */

/**
 * Check if we're currently in split print mode
 */
function is_split_mode() = ($split_print_mode == true && $split_current_index != undef);

/**
 * Get the current split bounds in wing coordinates
 * Returns object with start_z and end_z for the current split, or [0, wing_length] if not splitting
 */
function get_current_split_bounds(wing_length) = 
    is_split_mode() ? 
        object(
            start_z = max( $split_z_start, 0),
            end_z = min( $split_z_end, wing_length)
        ) : 
        object(
            start_z = 0,
            end_z = wing_length
        );

/**
 * Calculate the chord length at a specific wing position using normalized z (0 to 1)
 * @param normalized_z - Normalized position along the wing (0 = root, 1 = tip)
 * @param root_chord_mm - Root chord length in mm
 * @param tip_chord_mm - Tip chord length in mm
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function ChordLengthTrapezoidal(normalized_z, root_chord_mm, tip_chord_mm) = 
    root_chord_mm - (root_chord_mm - tip_chord_mm) * normalized_z;

/**
 * Calculate the chord length at a specific wing position using normalized z (0 to 1)
 * @param normalized_z - Normalized position along the wing (0 = root, 1 = tip)
 * @param root_chord_mm - Root chord length in mm
 * @param pow_factor - Elliptic distribution power factor
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function ChordLengthElliptical(normalized_z, root_chord_mm, pow_factor = 1.0) = 
    let(
        chord_ratio = pow(1 - pow(normalized_z, pow_factor), 1/pow_factor)
    ) root_chord_mm * chord_ratio;


// Function to create airfoil path from top and bottom surface lines
function create_airfoil_path_from_slice(slice) = 
    let(        
        af_top = [for (i = slice) [i.x, i.y]],       // Top surface line
        af_bottom = [for (i = slice) [i.x, i.z]],    // Bottom surface line

        // Reverse bottom surface to create continuous path
        bottom_reversed = [for (i = [len(af_bottom) - 2 : -1 : 1]) af_bottom[i]],

        // Combine top and bottom surfaces into single path
        combined_path = concat(af_top, bottom_reversed)
    ) combined_path;

function normalize_airfoil_slice(original_slice) = 
     [for (slice = original_slice)
            let(
                nx = slice.x/100,
                ntop = slice.y/100,
                nbottom = slice.z/100,
            ) [nx, ntop, nbottom]
        ];

function mirror_airfoil_slice(airfoil_slice) =
    [ for( slice = airfoil_slice )  [slice[0], abs(slice[1]), -abs(slice[1])] ];

function get_airfoil_path(airfoil, reference_chord_mm = 100) =
    let(
        base_path = (Render_Mode_Fast_PrecomputeAeroFoil || $preview)  
            ? airfoil.presampled_path
            : let(
                    // Modify the airfoil slice for printing, ensuring correct trailing edge thickness
                    modified_slice = modify_airfoil_slice_for_printing(airfoil.slice, airfoil.trailing_edge_thickness, reference_chord_mm),
                    full_path = create_airfoil_path_from_slice( modified_slice ),
                    sampled_path = (Render_Mode_Fast_ResampleAeroFoil || $preview) ? 
                        resample_path(full_path, n=30, keep_corners=10, closed=true)
                        : full_path
                ) sampled_path,
            // Scale the path to the current chord length
        outer_path = scale([reference_chord_mm, reference_chord_mm], p=base_path),
    ) outer_path;

/**
 * Create an offset (inward or outward) version of an airfoil path for hollow wing construction
 * Handles edge cases where chord length is too small relative to wall thickness
 * Uses airfoil thickness information for intelligent offset limits
 * @param airfoil - Airfoil object with path and thickness data
 * @param reference_chord_mm - Reference chord length in mm
 * @param wall_thickness - Offset distance in mm (positive = outward, negative = inward)
 * @param quality - Quality factor for offset smoothing (higher = smoother, default = 1)
 * @return offset airfoil path scaled to reference chord, or empty list if too small
 */
function get_offset_airfoil_path(airfoil, reference_chord_mm = 100, wall_thickness = -1.0, quality = 1) =
    let(
        // Calculate actual airfoil thickness at this chord length
        actual_max_thickness_mm = reference_chord_mm * airfoil.max_thickness_normalized,
                       
        // If chord is too small, return empty path (no hollow interior)
        chord_too_small = (wall_thickness*-3 > actual_max_thickness_mm),
        
        base_path = get_airfoil_path(airfoil, reference_chord_mm),

        // Start with the base airfoil path
        offset_path = chord_too_small ? [] : offset(base_path, r=wall_thickness, closed=true, quality=quality)
    ) 
    offset_path;    

// Function to modify airfoil data for 3D printing compatibility
// This function modifies both path and slice data consistently
// reference_chord is used to determine a scale for thickness calculation from normalized airfoil data
function modify_airfoil_slice_for_printing(normalized_slice, min_thickness_mm = 0.3, reference_chord_mm = 100) = 
    [for (slice = normalized_slice)
            let(
                nx = slice.x,
                ntop = slice.y,
                nbottom = slice.z,
                                
                // Get current thickness
                current_thickness = abs(ntop - nbottom),

                scaled_min_thickness = min_thickness_mm / max(reference_chord_mm,0.1), //< NOTE: Clampo to avoid division by zero at wing tip

                // Calculate thickness adjustment needed
                thickness_adjustment = (current_thickness < scaled_min_thickness) ? 
                    (scaled_min_thickness - current_thickness) / 2 : 0,

                // Apply modification to upper and lower surfaces
                modified_top = ntop + thickness_adjustment,
                modified_bottom = nbottom - thickness_adjustment
            ) [nx, modified_top, modified_bottom]
        ];


/**
 * Returns the appropriate airfoil path based on normalized wing position
 * Uses pre-computed paths from wing configuration for optimal performance
 * @param nz - Normalized Z position (0 to 1) along the wing span
 * @param wing_config - Wing configuration object containing pre-computed paths
 */
function get_airfoil_at_nz(nz, airfoil_config) = 
    let(
        // Choose appropriate path based on position
        airfoil = (nz > airfoil_config.tip_change_nz)  ?  airfoil_config.paths.tip :
                (nz > airfoil_config.center_change_nz) ?  airfoil_config.paths.mid :
                (nz > airfoil_config.root_change_nz) ?  airfoil_config.paths.root :
                                                       airfoil_config.paths.fuselage
    ) airfoil;

// Helper function to create a complete airfoil object from original airfoil data
// af_nslice: Original airfoil slice data from airfoil library
// trailing_edge_thickness: Minimum trailing edge thickness for 3D printing
// Returns an object containing all airfoil components (top, bottom, mid, path, preview paths)
function create_airfoil_object(af_nslice, trailing_edge_thickness ) = 
    let(
        // Precompute trailing edge thickness for preview
        reference_chord_mm = 100,

        // Modify airfoil slice data for 3D printing
        // NOTE: We only scale the source airfoil on preview but scale on slice-by-slice for render
        af_precomputed_slice = (Render_Mode_Fast_PrecomputeAeroFoil || $preview)
            ? modify_airfoil_slice_for_printing(af_nslice, trailing_edge_thickness, reference_chord_mm) 
            : af_nslice,
        
        // Extract surface lines from modified slice data
        af_top = [for (i = af_precomputed_slice) [i.x, i.y]],       // Top surface line
        af_bottom = [for (i = af_precomputed_slice) [i.x, i.z]],    // Bottom surface line
        
        // Mean camber line - midline halfway between top and bottom surfaces
        af_camber = [for (i = af_precomputed_slice) [i.x, (i.y + i.z) / 2]],
        
        // Create airfoil path from modified surface data
        af_path = create_airfoil_path_from_slice( af_precomputed_slice ),
        
        // Calculate maximum thickness directly from slice data
        // Find the maximum difference between top and bottom surfaces
        thickness_values = [for (i = af_precomputed_slice) abs(i.y - i.z)],
        max_thickness_normalized = max(thickness_values), // Maximum thickness in normalized coordinates
    ) object(
        slice = af_precomputed_slice,
        trailing_edge_thickness = trailing_edge_thickness,
        
        top = af_top,
        bottom = af_bottom,
        camber = af_camber,
        
        // Airfoil geometry information calculated from slice data
        max_thickness_normalized = max_thickness_normalized, // Maximum thickness as fraction of chord (0-1)

        presampled_path = ((Render_Mode_Fast_ResampleAeroFoil || $preview) 
            ? resample_path(af_path, n=30, keep_corners=10, closed=true)
            : af_path)
    );

// Helper function to access airfoil surface data
// Uses BOSL2 anchor constants for consistent interface
function get_airfoil_surface(surface_anchor=CENTER) = 
    surface_anchor == TOP ? af_root.top :
    surface_anchor == BOTTOM ? af_root.bottom :
    af_root.camber; // Default to mean camber for CENTER or any other value