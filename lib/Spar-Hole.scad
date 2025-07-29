
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

module CreateSparVoid(spar) {
    translate([0, spar.offset, 0]) 
    union() {
        spar_cylinder(spar, spar_void_radius(spar), "blue");
        
        if (Design_For_VaseMode) {
            vase_mode_void_cube(spar);
        }
    }
}