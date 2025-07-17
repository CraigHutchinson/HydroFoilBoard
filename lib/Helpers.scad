// Function to calculate the rib cord length
function ChordLengthAtIndex(index,
                            loc_wing_sections) = Main_Wing_Root_Chord_MM -
                                                 ((Main_Wing_Root_Chord_MM - Main_Wing_Tip_Chord_MM) / loc_wing_sections) * index;

function ChordLengthAtPosition(length_from_root_mm) = Main_Wing_Root_Chord_MM - (Main_Wing_Root_Chord_MM - Main_Wing_Tip_Chord_MM) *
                                                                               (length_from_root_mm / Main_Wing_mm);

// EaseInOut cubic function from t in [0,1] to eased progress [0,1]
function easeInOutCubic(t) = 
    t < 0.5? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;

// Function to calculate the rib cord length along an elliptical path
//	a: The semi-major axis of the ellipse (half the total span of the wing).
//	b: The semi-minor axis (maximum chord length, usually at the root).
//	x: The distance from the center (root) along the span.
//	elliptic_pow: Power factor for elliptic distribution (optional, defaults to global Main_Wing_Eliptic_Pow)
function ChordLengthAtEllipsePosition(a, b, x, elliptic_pow=undef) = 
    let(pow_factor = (elliptic_pow != undef) ? elliptic_pow : Main_Wing_Eliptic_Pow)
    2 * sqrt(((b / 2) * (b / 2) * (1 - pow((x * x) / (a * a), pow_factor))));

// Function using quadratic curve to create points that decrease towards the highest part of the wing
function f(i, numPoints, height) = height * (1 - pow((numPoints - i) / numPoints, 2));

// Get the starting point of the washout
function WashoutStart(count, max, wash_st, wing_mm) = (count >= max || f(count, max, wing_mm) > wash_st)
                                                          ? count
                                                          : WashoutStart(count + 1, max, wash_st, wing_mm);

// Find the aproximate airfoil hight a given distance from the TE
function AirfoilHeightAtPosition(path, distance, tolerance = 0.5) =
    let(points_within_tolerance = [for (pt = path) if (abs(pt[0] - distance) <= tolerance)
            pt], // Selecting points within the given tolerance
        max_y = max([for (pt = points_within_tolerance) pt[1]]),
        min_y = min([for (pt = points_within_tolerance) pt[1]]))
        abs(max_y - min_y); // Return the difference in y values of the top and bottom points

//Scales a path to the scale factor
function scalePath(points, scaleFactor) = [for (p = points)[p[0] * scaleFactor, p[1] * scaleFactor]];        

// Function to split a module into printable parts along the Z axis
module split_into_parts( total_length, build_area, scale=1.0, bbox=af_bbox, print_height_mm=0) {
    splits = ceil(total_length / (build_area.z * scale));
    splits_length = total_length / splits;
    // If print_height_mm > 0, only print up to that height from the bottom of each part
    part_height = (print_height_mm > 0 && print_height_mm < splits_length) ? print_height_mm : splits_length;

    for (i = [0:splits-1]) {
        fwd(i * (bbox.w - bbox.z + (build_area.x / splits)))
        intersection() {
            down(i * splits_length) children();
            cube([build_area.x, build_area.y, part_height], anchor=BOTTOM+LEFT);
        }
    }
}