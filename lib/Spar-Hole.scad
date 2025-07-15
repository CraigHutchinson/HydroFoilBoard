extra_spar_hole_bot_offset=0.2;

module CreateSparHole( spar )
{

    translate([ 0, spar_hole_offset(spar), -0.01 ]) union()
    {
        if ( Design_For_VaseMode )
        {
            translate([ spar_hole_perc(spar) / 100 * wing_root_chord_mm, 0, 0 ]) # difference()
            {
                translate([ 0, spar_hole_size(spar) / 2 - (slice_gap_width/2), 0 ]) cube([ slice_gap_width, 50, spar_hole_length(spar) + 10 ]);

                translate([ -5, spar_hole_size(spar) / 2, spar_hole_length(spar) ]) rotate([ 35, 0, 0 ]) cube([ 10, 50, 20 ]);
            }
        }

        color("red") translate([ spar_hole_perc(spar) / 100 * wing_root_chord_mm, 0, 0 ])
            cylinder(h = spar_hole_length(spar), r = spar_hole_size(spar) / 2);
    }
}

module CreateSparVoid( spar )
{
    translate([ 0, spar_hole_offset-extra_spar_hole_bot_offset, 0 ]) 
    union()
    {
        color("blue") 
        translate([ spar_hole_perc(spar) / 100 * wing_root_chord_mm, 0, 0 ])
            cylinder(h = spar_hole_length(spar), r = spar_hole_size(spar) / 2 + (spar_hole_void_clearance / 2));
        color("brown") 
        translate([ spar_hole_perc(spar) / 100 * wing_root_chord_mm - ((spar_hole_size(spar) + spar_hole_void_clearance)/2), 0, 0 ])
        if ( Design_For_VaseMode )
        {
            cube([ spar_hole_size(spar) + spar_hole_void_clearance, 100, spar_hole_length(spar) ]);
        }
    }
  }