include <Wing-Creator.scad>

CamberAdjust = 0; //% to increase or decrease the camber for difficult airfoil

module CamberVoidLE(airfoil_slice_path)
{
    polygon(points = airfoil_slice_path);
    translate([ slice_ext_width * 2, 0, 0 ]) polygon(points = airfoil_slice_path);
    translate([ -slice_ext_width * 2, 0, 0 ]) polygon(points = airfoil_slice_path);
}

module CamberVoidTE(airfoil_slice_path)
{
    polygon(points = airfoil_slice_path);
    translate([ 0, slice_ext_width, 0 ]) polygon(points = airfoil_slice_path);
    translate([ 0, -slice_ext_width, 0 ]) polygon(points = airfoil_slice_path);
}

function max_x(points, idx = 0, max_vals = undef,
               max_x_val = -1e10) = (idx == len(points)) ? max_vals
                                    : (points[idx][0] > max_x_val)
                                        ? max_x(points, idx + 1, [points[idx]], points[idx][0])
                                    : (points[idx][0] == max_x_val)
                                        ? max_x(points, idx + 1, concat(max_vals, [points[idx]]), max_x_val)
                                        : max_x(points, idx + 1, max_vals, max_x_val);

function max_y(points, idy = 0, max_val = [ -1e10, -1e10 ]) =
    (idy == len(points)) ? max_val : max_y(points, idy + 1, points[idy][1] > max_val[1] ? points[idy] : max_val);

function min_x(points, idx = 0, min_val = [ 1e10, 1e10 ]) =
    (idx == len(points)) ? min_val : min_x(points, idx + 1, points[idx][0] < min_val[0] ? points[idx] : min_val);

function min_y(points, idy = 0, min_val = [ 1e10, 1e10 ]) =
    (idy == len(points)) ? min_val : min_y(points, idy + 1, points[idy][1] < min_val[1] ? points[idy] : min_val);

function get_y_center_point(points) =
    let(min_point = min_y(points),
        max_point = max_y(points))[(min_point[0] + max_point[0]) / 2, (min_point[1] + max_point[1]) / 2];

function trailing_edge_center(AFPoints) =
    let(trailing_points = max_x(AFPoints))[trailing_points[0][0], avg_y(trailing_points)];

function avg_y(points) = sum_y(points) / len(points);

function tail(points, idx = 1) = idx >= len(points) ? [] : concat([points[idx]], tail(points, idx + 1));

function sum_y(points) = len(points) == 0 ? 0 : points[0][1] + sum_y(tail(points));

module CamberVoidLE(AFPoints)
{
    y_diff = max_y(AFPoints)[1] - min_y(AFPoints)[1];

    union()
    {
        color("red") hull()
        {
            translate(min_x(AFPoints)) cube([ XandZHeight, CenterGap, XandZHeight ], center = true);
            translate([ 0, (CamberAdjust / 100) * (y_diff / 2), 0 ]) translate(get_y_center_point(AFPoints))
                cube([ XandZHeight, CenterGap, XandZHeight ], center = true);
        }
    }
}

module CamberVoidTE(AFPoints)
{
    y_diff = max_y(AFPoints)[1] - min_y(AFPoints)[1];
    union()
    {
        color("blue") hull()
        {
            translate([ 0, (CamberAdjust / 100) * (y_diff / 2), 0 ]) translate(get_y_center_point(AFPoints))
                cube([ XandZHeight, CenterGap, XandZHeight ], center = true);
            translate(trailing_edge_center(AFPoints)) cube([ XandZHeight, CenterGap, XandZHeight ], center = true);
        }
    }
}

module GridWashoutSlice(i, scale_factor, current_chord_mm, LE)
{

    washout_start_point = (wing_mode == 1) ? (Main_Wing_Sections * (Main_Wing_Washout_Start / 100))
                                           : WashoutStart(0, Main_Wing_Sections, Main_Wing_Washout_Start, Main_Wing_mm);
    washout_deg_frac = Main_Wing_Washout_Deg / (Main_Wing_Sections - washout_start_point);
    washout_deg_amount = (washout_start_point - i) * washout_deg_frac;
    rotate_point = current_chord_mm * (Main_Wing_Washout_Pivot_Perc / 100);

    translate([ rotate_point, 0, 0 ]) rotate(washout_deg_amount) translate([ -rotate_point, 0, 0 ])
        GridESlice(i, scale_factor, LE);
}

module GridESlice(i, scale_factor, LE)
{

    if (i > Main_Wing_Sections * (tip_airfoil_change_perc / 100))
    {
        if (LE)
        {
            CamberVoidLE(scale([scale_factor, scale_factor], p=af_vec_path_tip));
        }
        else
        {
            CamberVoidTE(scale([scale_factor, scale_factor], p=af_vec_path_tip));
        }
    }
    else if (i > Main_Wing_Sections * (center_airfoil_change_perc / 100))
    {
        if (LE)
        {
            CamberVoidLE(scale([scale_factor, scale_factor], p=af_vec_path_mid));
        }
        else
        {
            CamberVoidTE(scale([scale_factor, scale_factor], p=af_vec_path_mid));
        }
    }
    else
    {
        if (LE)
        {
            CamberVoidLE(scale([scale_factor, scale_factor], p=af_vec_path_root));
        }
        else
        {
            CamberVoidTE(scale([scale_factor, scale_factor], p=af_vec_path_root));
        }
    }
}

module GridSlice(z_location, i, LE)
{
    current_chord_mm = (wing_mode == 1) ? ChordLengthAtIndex(i, Main_Wing_Sections)
                                        : ChordLengthElliptical(z_location / Main_Wing_mm, Main_Wing_Root_Chord_MM, Main_Wing_Eliptic_Pow);

    scale_factor = current_chord_mm / 100;
    translate([ 0, 0, z_location ]) translate([ -MainWing_Center_Line_Perc / 100 * current_chord_mm, 0, 0 ])

        if (Main_Wing_Washout_Deg > 0 && ((wing_mode > 1 && i > WashoutStart(0, Main_Wing_Sections, Main_Wing_Washout_Start, Main_Wing_mm)) ||
                                (wing_mode == 1 && i > (Main_Wing_Sections * (Main_Wing_Washout_Start / 100)))))
    {
        GridWashoutSlice(i, scale_factor, current_chord_mm, LE);
    }
    else
    {
        GridESlice(i, scale_factor, LE);
    }
}

module CreateGridVoid()
{
    wing_section_mm = Main_Wing_mm / Main_Wing_Sections;
    if (wing_mode == 1)
    {
        translate([ Main_Wing_Root_Chord_MM * (MainWing_Center_Line_Perc / 100), 0, 0 ]) union()
        {
            color("red") union()
            {
                for (i = [0:Main_Wing_Sections])
                {
                    hull()
                    {
                        GridSlice(wing_section_mm * i, i, true);
                        GridSlice(wing_section_mm * (i + 1), i + 1, true);
                    }
                }
            }
            color("green") union()
            {
                for (i = [0:Main_Wing_Sections])
                {
                    hull()
                    {
                        GridSlice(wing_section_mm * i, i, false);
                        GridSlice(wing_section_mm * (i + 1), i + 1, false);
                    }
                }
            }
        }
    }
    else
    {
        translate([ Main_Wing_Root_Chord_MM * (MainWing_Center_Line_Perc / 100), 0, 0 ]) union()
        {
            color("red") union()
            {
                for (i = [0:Main_Wing_Sections])
                {
                    pos = QuadraticWingPosition(i, Main_Wing_Sections, Main_Wing_mm);
                    npos = QuadraticWingPosition((i + 1), Main_Wing_Sections, Main_Wing_mm);
                    hull()
                    {
                        GridSlice(pos, i, true);
                        GridSlice(npos, (i + 1), true);
                    }
                }
            }
            color("blue") union()
            {
                for (i = [0:Main_Wing_Sections])
                {
                    pos = QuadraticWingPosition(i, Main_Wing_Sections, Main_Wing_mm);
                    npos = QuadraticWingPosition((i + 1), Main_Wing_Sections, Main_Wing_mm);
                    hull()
                    {
                        GridSlice(pos, i, false);
                        GridSlice(npos, (i + 1), false);
                    }
                }
            }
        }
    }
}