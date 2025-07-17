
include <Wing-Creator.scad>
x_scale_factor=0.9;
y_scale_factor=0.5;
y_cor = 0;
tip_offset=30;
rib_void_offset=15;

module CreateRibVoids()
{
    void_length = Main_Wing_MM-tip_offset;

    color("black")

    intersection()
    {
        x_cor = (Main_Wing_Root_Chord_MM-(Main_Wing_Root_Chord_MM*x_scale_factor))/2;
        translate([x_cor,y_cor,0])
        scale([x_scale_factor, y_scale_factor,1])
        CreateWing(true);

        union(){
            translate([5,-40,-0.02])
            cube([25,80,void_length]);

            translate([40,-40,-0.02])
            cube([25,80,void_length]);

            translate([75,-40,-0.02])
            cube([25,80,void_length]);

        }
    }
}

module CreateRibVoids2()
{
    void_length = wing_mm-tip_offset;
    space_bet_spars = (Main_Wing_Root_Chord_MM-(spar_offset*2))/spar_num;
    space_bet_ribs = (wing_mm-(rib_offset*2))/(rib_num-1);

    color("black")

    intersection()
    {
        x_cor = (Main_Wing_Root_Chord_MM-(Main_Wing_Root_Chord_MM*x_scale_factor))/2;
        translate([x_cor,y_cor,0])
        scale([x_scale_factor, y_scale_factor,1])
        CreateWing(true);

        union(){
            translate([spar_offset,0,0])
            for (i = [0:spar_num]) {
                translate([space_bet_spars*i+(rib_void_offset/2),-Main_Wing_Root_Chord_MM/3/2,0])
                color("orange")
                cube([space_bet_spars-rib_void_offset, Main_Wing_Root_Chord_MM/3, Main_Wing_MM]);
            }

            translate([0,0,rib_offset])
            for (i = [0:rib_num]) {
            translate([0,-Main_Wing_Root_Chord_MM/3/2,space_bet_ribs*i+10])
            color("green")
            rotate([0,55,0])
            cube([Main_Wing_Root_Chord_MM*2, Main_Wing_Root_Chord_MM/3, space_bet_ribs-40]);
            }
        }
    }
}




