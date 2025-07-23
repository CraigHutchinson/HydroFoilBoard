// Function to calculate the rib cord length
function ChordLengthAtIndex(index,
                            loc_wing_sections) = Main_Wing_Root_Chord_MM -
                                                 ((Main_Wing_Root_Chord_MM - Main_Wing_Tip_Chord_MM) / loc_wing_sections) * index;

function ChordLengthTrapezoidal(length_from_root_mm) 
= Main_Wing_Root_Chord_MM - (Main_Wing_Root_Chord_MM - Main_Wing_Tip_Chord_MM) 
* (length_from_root_mm / Main_Wing_mm);

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
 * Returns [start_z, end_z] for the current split, or [0, wing_length] if not splitting
 */
function get_current_split_bounds(wing_length) = 
    is_split_mode() ? [$split_z_start, $split_z_end] : [0, wing_length];

/**
 * Calculate the chord length at a specific wing position using index (wing_mode == 1)
 * @param z_location - Z position of this slice along the wing
 * @param root_chord_mm - Root chord length in mm
 * @param tip_chord_mm - Tip chord length in mm
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function ChordLengthTrapezoidal(z_location, root_chord_mm, tip_chord_mm) = 
    let(
        tip_to_root_ratio = tip_chord_mm / root_chord_mm,
        progress = z_location / wing_mm,
        current_chord_mm = root_chord_mm * (1 - progress * (1 - tip_to_root_ratio))
    ) current_chord_mm;

/**
 * Calculate the chord length at a specific wing position using z_location (wing_mode > 1)
 * @param z_location - Z position of this slice along the wing
 * @param wing_mm - Wing half-span length
 * @param root_chord_mm - Root chord length in mm
 * @param pow_factor - Elliptic distribution power factor
 * @return current_chord_mm - Chord length in millimeters at this position
 */
function ChordLengthElliptical(z_location, wing_mm, root_chord_mm, pow_factor = 1.0) = 
        let(
        // Fix: The formula should use wing_mm and root_chord_mm correctly
        normalized_pos = z_location / wing_mm,  // 0 to 1
        chord_ratio = pow(1 - pow(normalized_pos, pow_factor), 1/pow_factor)
    ) root_chord_mm * chord_ratio;

// Function to calculate the theoretical scale factor for elliptic wings
// This relates the average chord to root chord based on the elliptic power factor
function calculate_elliptic_scale_factor(elliptic_power) = 
    let(
        // For an elliptic wing: chord(x) = 2 * sqrt((b/2)² * (1 - (x²/a²)^p))
        // where b is root chord, a is half-span, p is elliptic power
        // 
        // The average chord can be calculated as:
        // c_avg = (1/a) * ∫[0 to a] chord(x) dx
        // 
        // For the scale factor: c_root = c_avg * scale_factor
        // 
        // Mathematical analysis shows:
        // - p = 1.0: circular arc, c_avg/c_root = π/4, so scale_factor = 4/π ≈ 1.2732
        // - p = 1.5: empirically validated as 1.18853 for AXIS PNG 1150
        // - p = 2.0: true ellipse, c_avg/c_root = π/4, so scale_factor = 4/π ≈ 1.2732
        // 
        // The function has a minimum around p=1.5 due to the compression effect
        
        scale_factor = 
            (elliptic_power <= 1.0) ? 4/PI :  // 4/π for circular arc
            (elliptic_power <= 1.5) ? 4/PI  - (elliptic_power - 1.0) * 0.16934 :  // Exact to 1.18853 at p=1.5
            (elliptic_power <= 2.0) ? 1.18853 + (elliptic_power - 1.5) * 0.16934 : // Symmetric return to 4/π
            4/PI  // 4/π for higher powers (true ellipse and beyond)
    ) scale_factor;