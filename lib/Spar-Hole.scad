
// Helper function to calculate spar hole x-position
function spar_x_position(spar) = spar.x;

// Helper function to calculate spar hole radius
function spar_hole_radius(spar) = spar.hole_diameter / 2;

// Helper function to calculate spar void radius
function spar_void_radius(spar) = spar_hole_radius(spar) + (spar_hole_void_clearance / 2);

// Helper module for the basic spar cylinder
module spar_cylinder(spar, radius, color_name) {
    color(color_name) 
    translate([spar_x_position(spar), 0, 0])
        cylinder(h = spar.length, r = radius);
}

// Helper module for vase mode spar slot
module vase_mode_spar_slot(spar) {
    translate([spar_x_position(spar), 0, 0]) 
    difference() {
        translate([0, spar_hole_radius(spar) - (slice_gap_width/2), 0]) 
            cube([slice_gap_width, 50, spar.length + 10]);
        
        translate([-5, spar_hole_radius(spar), spar.length]) 
            rotate([35, 0, 0]) 
            cube([10, 50, 20]);
    }
}

// Helper module for vase mode void cube
module vase_mode_void_cube(spar) {
    color("brown") 
    translate([spar_x_position(spar) - ((spar.hole_diameter + spar_hole_void_clearance)/2), 0, 0])
        cube([spar.hole_diameter + spar_hole_void_clearance, 100, spar.length]);
}

module CreateSparHole(spar) {
    translate([0, spar.offset, -0.01]) 
    union() {
        if (Design_For_VaseMode) {
            # vase_mode_spar_slot(spar);
        }
        
        spar_cylinder(spar, spar_hole_radius(spar), "red");
    }
}

/**
 * Create a spar tube (larger cylinder) to provide material around a spar hole
 * Used for hollow wing construction to provide solid material for spar mounting
 * @param spar - Spar hole configuration object with position and dimensions
 */
module CreateSparTube(spar) {
    translate([spar.x, spar.offset, 0]) {
        cylinder(
            h = spar.length, 
            d = spar.hole_diameter + 2.4 // Add 1.2mm wall thickness on each side (2 * 1.2 = 2.4)
        );
    }
}

/**
 * Create an enhanced spar tube with smooth transition to structural spar bar
 * Transitions from cylindrical base to rectangular structural spar shape at top
 * @param spar - Spar hole configuration object with position and dimensions
 * @param wing_config - Wing configuration object for chord calculations
 * @param transition_height - Height over which to transition from cylinder to rectangular bar (mm)
 */
module CreateSparTubeWithTransition(spar, wing_config, transition_height = 20) {
    translate([spar.x, spar.offset, 0]) {
        // Base cylinder for the main tube body
        base_cylinder_height = spar.length;
        tube_diameter = spar.hole_diameter + 2.4; // 1.2mm wall thickness on each side
        
        union() {
            // Base cylindrical section
            if (base_cylinder_height > 0) {
                cylinder(
                    h = base_cylinder_height,
                    d = tube_diameter
                );
            }
            
            // Transition section using hull() to morph from cylinder to rectangular bar
            translate([0, 0, max(0, base_cylinder_height)]) {
                hull() {
                    // Bottom: cylinder cross-section
                    cylinder(h = 0.1, d = tube_diameter);
                    
                    // Top: rectangular structural spar bar cross-section
                    translate([0, 0, transition_height - 0.1]) {
                        // Calculate dimensions to match the grid structure exactly
                        root_chord = get_root_chord_mm(wing_config) / Build_Scale; // Convert to unscaled units like grid does
                        
                        // Use the same thickness calculation as the grid structure
                        spar_thickness = spar.hole_diameter / 2; // Use half spar diameter as requested
                        spar_width = root_chord / 3; // Match grid structure width
                        
                        // Position the bar to match grid structure centering
                        // Grid places bars at y = -root_chord/3/2, but we're already offset by spar.offset
                        // So we need to adjust relative to our current position
                        grid_y_center = -root_chord / 3 / 2; // Grid's y-center position
                        local_y_offset = grid_y_center - (spar.offset / Build_Scale); // Adjust for our current offset
                        
                        // Create rectangular bar centered to match grid structure
                        translate([-spar_thickness/2, local_y_offset, 0])
                            cube([spar_thickness, spar_width, 0.1]);
                    }
                }
            }
        }
    }
}

module CreateSparVoid(spar) {
    translate([0, spar.offset, 0]) 
    union() {
        spar_cylinder(spar, spar_void_radius(spar), "blue");
        
        if (Design_For_VaseMode) {
            vase_mode_void_cube(spar);
        }
    }
}