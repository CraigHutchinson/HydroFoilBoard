
module Grid(x, z, space)
{
    for (i = [0:1:x - 1])
    {
        for (j = [0:1:z - 1])
        {
            translate([ i * space, 0, j * space ])
            {
                children();
            }
        }
    }
}

module GridHoles(x, z, space)
{
    for (i = [0:1:x - 1])
    {
        for (j = [0:1:z - 1])
        {
            translate([ i * space, 0, j * space ])
            {
                children();
            }
        }
    }
}

module StructureGrid(wing_mm, root_chord, size_factor)
{

    grid_height = root_chord;
    rib_grid_distance = root_chord / size_factor / sqrt(2);
    grid_diagonal_distance = rib_grid_distance * sqrt(2);
    union() Grid(ceil(root_chord / grid_diagonal_distance), ceil(wing_mm / grid_diagonal_distance) + 1,
                 grid_diagonal_distance) rotate([ 0, 45, 0 ]) translate([ 0, -grid_height / 2, 0 ]) difference()
    {
        cube([ rib_grid_distance + slice_gap_width / 2, grid_height, rib_grid_distance + slice_gap_width / 2 ]);
        translate([ slice_gap_width / 2, 0, slice_gap_width / 2 ]) color("red")
            cube([ rib_grid_distance - slice_gap_width / 2, grid_height, rib_grid_distance - slice_gap_width / 2 ]);
    }
}

module StructureGridHoles(wing_mm, root_chord, size_factor)
{

    grid_height = root_chord;
    rib_grid_distance = root_chord / size_factor / sqrt(2);
    grid_diagonal_distance = rib_grid_distance * sqrt(2);
    // union()
    GridHoles(ceil(root_chord / grid_diagonal_distance), ceil(wing_mm / grid_diagonal_distance) + 1,
              grid_diagonal_distance) rotate([ 0, 45, 0 ]) translate([ 0, -grid_height / 2, 0 ]) color("red")
        translate([ -grid_height / 2, 0, (grid_height * 0.1) ]) scale([ 0.9, 1, 0.9 ])
            cube([ root_chord, grid_height, rib_grid_distance + slice_gap_width / 2 ]);
}


module StructureSparGrid(wing_mm, root_chord, size_factor, spar_num, spar_offset, rib_num, rib_offset)
{

    space_bet_spars = (root_chord - (spar_offset * 2)) / (spar_num - 1);
    space_bet_ribs = (wing_mm - (rib_offset * 2)) / (rib_num - 1);

    difference()
    {
        union()
        {
            translate([ spar_offset, 0, 0 ]) 
            for (i = [0:spar_num - 1])
            {
                    translate([ space_bet_spars * i, -root_chord / 3 / 2, 0 ]) color("orange")
                        cube([ slice_gap_width, root_chord / 3, wing_mm ]);
            }
            for (i = [0:rib_num])
            {
                translate([ 0, -root_chord / 3 / 2, space_bet_ribs * i ]) color("green") rotate([ 0, 55, 0 ])
                    cube([ root_chord * 2, root_chord / 3, slice_gap_width ]);
            }
        }
    }
}

/**
 * Advanced spar grid that uses spar configuration object for precise positioning
 * Aligns grid structure with actual spar hole positions for optimal integration
 * 
 * @param wing_config - Wing configuration object
 * @param spar_config - Spar configuration object containing spar definitions
 */
module StructureSparGridConfigured(wing_config, spar_config)
{
    wing_mm = wing_config.wing_mm;
    root_chord = get_root_chord_mm(wing_config);
    grid_config = spar_config.grid;
    
    // Get spar positions to use for grid alignment
    grid_spars = grid_config.structural_only ? 
        get_structural_spars(spar_config) : 
        spar_config.spars;
    
    // Rib spacing calculation
    space_bet_ribs = (wing_mm - (grid_config.rib_offset * 2)) / (grid_config.rib_count - 1);

    difference()
    {
        union()
        {
            // SPAR GRID LINES - Use actual spar positions with rod-specific thickness
            for (spar = grid_spars)
            {
                x_pos = get_spar_x_mm(spar, wing_config) / Build_Scale; // Convert back to unscaled units
                
                // Determine thickness based on spar rod diameter
                spar_thickness = (spar.type == "paired") ? 
                    // For paired spars, use the larger of the two rod diameters
                    ((spar.top_config.rod_diameter == Spar_Rod_Large_Diameter || spar.bottom_config.rod_diameter == Spar_Rod_Large_Diameter) ? 
                        grid_config.large_rod_thickness : grid_config.small_rod_thickness) :
                    // For single spars, check rod diameter directly
                    (spar.rod_diameter == Spar_Rod_Large_Diameter ? 
                        grid_config.large_rod_thickness : grid_config.small_rod_thickness);
                
                // Center the spar bar on the actual spar position
                translate([ x_pos - spar_thickness/2, -root_chord / 3 / 2, 0 ]) color("orange")
                    cube([ spar_thickness, root_chord / 3, wing_mm ]);
            }
            
            // RIB GRID LINES - Cross-ribs at regular intervals
            for (i = [0:grid_config.rib_count])
            {
                translate([ 0, -root_chord / 3 / 2, space_bet_ribs * i ]) color("green") rotate([ 0, 55, 0 ])
                    cube([ root_chord * 2, root_chord / 3, grid_config.rib_thickness ]);
            }
        }
    }
}

/*module StructureSparVoid(wing_mm, root_chord, size_factor, spar_num, spar_offset, spar_hole_num, rib_num, rib_offset)
{

    space_bet_spars = (root_chord - (spar_offset * 2)) / spar_num - 1;

    translate([ spar_offset, 0, 0 ]) for (i = [0:spar_num - 1])
    {
        if (spar_hole_num == i + 1)
        {
            translate([ space_bet_spars * i, spar_hole_offset, 0 ]) color("brown") union()
            {
                // cylinder(r = 4, h = wing_mm-(wing_mm*0.2));
                cube([ 8, root_chord / 3, wing_mm - (wing_mm * 0.2) ]);
            }
        }
    }
}*/