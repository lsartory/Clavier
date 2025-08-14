// Clavier | clavier.scad
// Copyright (c) 2025 L. Sartory
// SPDX-License-Identifier: CERN-OHL-P-2.0

/************************************************/

include <BOSL2/std.scad>
include <BOSL2/screws.scad>

/************************************************/

$fa = 1.00;
$fs = $preview ? 1.50 : 0.10;
epsilon = 0.01;

/************************************************/

pcb_width     = 431.50;
pcb_height    = 125.50;
pcb_thickness =   1.60;
pcb_corner    =   5.00;

/************************************************/

housing_thickness = 11.50;
bottom_thickness  =  2.50;
border_width      =  1.50;
ledge_width       =  1.00;
bottom_offset     =  5.00;
gap               =  0.40;
housing_chamfer   =  1.00;

openings_ext      = 10.00;
openings_margin   =  0.50;

screw_type        = "M3,9";
mounting_diameter = 7.00;
mounting_base     = 8.00;
mounting_delta    = 0.20;
rib_height        = 5.00;
rib_rounding      = 2.50;

supports = [
    [11.50,  -23.75], [135.00,  -23.75], [277.50,  -23.75], [420.00, -23.75],
    [25.75, -104.50], [215.75, -104.50], [391.50, -104.50]
];

usb_c =  [405.75, -1.80];
usb_a = [[382.00, -4.30], [355.75, -4.30]];
jtag  =  [289.38, -1.40];

usb_c_dim = [9.00, 3.20, 1.00];
usb_c_ext = 6.00;

usb_a_dim = [14.40, 7.20, 2.00];
usb_a_ext = 8.00;

jtag_dim  = [10.20, 2.60, 0.50];
jtag_ext  = 2.00;

/************************************************/

module rounded_rect(w, h, t, c) {
    cuboid([w, h, t], anchor = BACK+LEFT+BOTTOM, rounding = c, edges = [FWD+LEFT, FWD+RIGHT, BACK+LEFT, BACK+RIGHT]);
}

module housing() {
    difference() {
        // Main body
        hull() {
            // Top shape
            translate([-border_width - gap, border_width + gap, 0])
                rounded_rect(pcb_width + 2 * (border_width + gap), pcb_height + 2 * (border_width + gap), pcb_thickness, pcb_corner + border_width + gap);
            // Bottom shape
            translate([-border_width - gap, border_width + gap, -housing_thickness])
                rounded_rect(pcb_width + 2 * (border_width + gap), pcb_height + bottom_offset + 2 * (border_width + gap), epsilon, pcb_corner + border_width + gap);
        }

        // Inside ledge
        translate([-gap, gap, 0])
            rounded_rect(pcb_width + 2 * gap, pcb_height + 2 * gap, pcb_thickness + epsilon, pcb_corner + gap);
        // Inside hollowing
        translate([ledge_width, -ledge_width, -housing_thickness + bottom_thickness])
            cuboid([pcb_width - 2 * ledge_width, pcb_height - 2 * ledge_width, housing_thickness + bottom_thickness], anchor = BACK+LEFT+BOTTOM, rounding = pcb_corner - ledge_width);

        // Top chamfers (not great, but it works...)
        translate([-border_width - gap, border_width + gap, pcb_thickness])
            rounding_edge_mask(l = pcb_width + (border_width + gap) * 2, r = housing_chamfer, orient = RIGHT, spin = 270, anchor = BOTTOM);
        translate([-border_width - gap, -pcb_height - border_width - gap * 2, pcb_thickness]) // TODO: this does not work right for other values
            rounding_edge_mask(l = pcb_width + (border_width + gap) * 2, r = housing_chamfer, orient = RIGHT, anchor = BOTTOM);
        translate([-border_width - gap, border_width + gap, pcb_thickness])
            rounding_edge_mask(l = pcb_height + (border_width + gap) * 2, r = housing_chamfer, orient = FRONT, spin = 270, anchor = BOTTOM);
        translate([pcb_width + border_width + gap, border_width + gap, pcb_thickness])
            rounding_edge_mask(l = pcb_height + (border_width + gap) * 2, r = housing_chamfer, orient = FRONT, spin = 180, anchor = BOTTOM);
        translate([pcb_corner, -pcb_corner, pcb_thickness])
            back_half() left_half() rounding_cylinder_mask(r = pcb_corner + border_width + gap, rounding = housing_chamfer, orient = TOP);
        translate([pcb_width - pcb_corner, -pcb_corner, pcb_thickness])
            back_half() right_half() rounding_cylinder_mask(r = pcb_corner + border_width + gap, rounding = housing_chamfer, orient = TOP);
        translate([pcb_corner, -pcb_height + pcb_corner - gap, pcb_thickness])
            front_half() left_half() rounding_cylinder_mask(r = pcb_corner + border_width + gap, rounding = housing_chamfer, orient = TOP);
        translate([pcb_width - pcb_corner, -pcb_height + pcb_corner - gap, pcb_thickness])
            front_half() right_half() rounding_cylinder_mask(r = pcb_corner + border_width + gap, rounding = housing_chamfer, orient = TOP);

        // Bottom chamfers
        translate([-border_width - gap, border_width + gap, -housing_thickness])
            chamfer_edge_mask(l = pcb_width + (border_width + gap) * 2, chamfer = housing_chamfer, orient = RIGHT, anchor = BOTTOM);
        translate([-border_width - gap, -pcb_height - bottom_offset - border_width - gap, -housing_thickness])
            chamfer_edge_mask(l = pcb_width + (border_width + gap) * 2, chamfer = housing_chamfer, orient = RIGHT, anchor = BOTTOM);
        translate([-border_width - gap, border_width + gap, -housing_thickness])
            chamfer_edge_mask(l = pcb_height + bottom_offset + (border_width + gap) * 2, chamfer = housing_chamfer, orient = FRONT, anchor = BOTTOM);
        translate([pcb_width + border_width + gap, border_width + gap, -housing_thickness])
            chamfer_edge_mask(l = pcb_height + bottom_offset + (border_width + gap) * 2, chamfer = housing_chamfer, orient = FRONT, anchor = BOTTOM);
        translate([pcb_corner, -pcb_corner, -housing_thickness])
            back_half() left_half() chamfer_cylinder_mask(r = pcb_corner + border_width + gap, chamfer = housing_chamfer, orient = BOTTOM);
        translate([pcb_width - pcb_corner, -pcb_corner, -housing_thickness])
            back_half() right_half() chamfer_cylinder_mask(r = pcb_corner + border_width + gap, chamfer = housing_chamfer, orient = BOTTOM);
        translate([pcb_corner, -pcb_height + pcb_corner - bottom_offset, -housing_thickness])
            front_half() left_half() chamfer_cylinder_mask(r = pcb_corner + border_width + gap, chamfer = housing_chamfer, orient = BOTTOM);
        translate([pcb_width - pcb_corner, -pcb_height + pcb_corner - bottom_offset, -housing_thickness])
            front_half() right_half() chamfer_cylinder_mask(r = pcb_corner + border_width + gap, chamfer = housing_chamfer, orient = BOTTOM);

        // USB C opening
        translate([usb_c[0], 0, usb_c[1] + openings_ext / 2]) cuboid([usb_c_dim[0] + usb_c_ext + openings_margin, (border_width + gap) * 2, usb_c_dim[1] + usb_c_ext + openings_margin + openings_ext], anchor = FRONT, except = [FRONT, BACK], rounding = usb_c_dim[2] * 2);
        translate([usb_c[0], 0, usb_c[1] + openings_ext / 2]) cuboid([usb_c_dim[0] + openings_margin, (border_width + gap) * 4, usb_c_dim[1] + openings_margin + openings_ext], except = [FRONT, BACK], rounding = usb_c_dim[2]);

        // USB openings
        translate([usb_a[0][0], 0, usb_a[0][1]]) cuboid([usb_a_dim[0] + usb_a_ext + openings_margin, (border_width + gap) * 2, usb_a_dim[1] + usb_a_ext + openings_margin + openings_ext], anchor = FRONT, except = [FRONT, BACK], rounding = usb_a_dim[2] * 2);
        translate([usb_a[0][0], 0, usb_a[0][1] + openings_ext / 2]) cuboid([usb_a_dim[0] + openings_margin, (border_width + gap) * 4, usb_a_dim[1] + openings_margin + openings_ext], except = [FRONT, BACK], rounding = usb_a_dim[2]);
        translate([usb_a[1][0], 0, usb_a[1][1]]) cuboid([usb_a_dim[0] + usb_a_ext + openings_margin, (border_width + gap) * 2, usb_a_dim[1] + usb_a_ext + openings_margin + openings_ext], anchor = FRONT, except = [FRONT, BACK], rounding = usb_a_dim[2] * 2);
        translate([usb_a[1][0], 0, usb_a[1][1] + openings_ext / 2]) cuboid([usb_a_dim[0] + openings_margin, (border_width + gap) * 4, usb_a_dim[1] + openings_margin + openings_ext], except = [FRONT, BACK], rounding = usb_a_dim[2]);

        // JTAG opening
        translate([jtag[0], 0, jtag[1] + openings_ext / 2]) cuboid([jtag_dim[0] + jtag_ext + openings_margin, (border_width + gap) * 2, jtag_dim[1] + jtag_ext + openings_margin + openings_ext], anchor = FRONT, except = [FRONT, BACK], rounding = jtag_dim[2] * 2);
        translate([jtag[0], 0, jtag[1] + openings_ext / 2]) cuboid([jtag_dim[0] + openings_margin, (border_width + gap) * 4, jtag_dim[1] + openings_margin + openings_ext], except = [FRONT, BACK], rounding = jtag_dim[2]);

        // TODO: Stabilizers openings
    }
}

/************************************************/

module supports() {
    for (i = supports) {
        translate(i) cyl(l = housing_thickness - bottom_thickness + epsilon - mounting_delta, r = mounting_diameter / 2, rounding1 = -mounting_base, rounding2 = 1.0 - mounting_delta, anchor = TOP);
    }
}

/************************************************/

module rib(start, end) {
    delta_x = end[0] - start[0];
    delta_y = end[1] - start[1];
    length = sqrt(delta_x * delta_x + delta_y * delta_y);
    angle  = atan2(delta_y, delta_x);
    translate(start)
        diff()
        cuboid([length, mounting_diameter, rib_height + epsilon], spin = angle, anchor = LEFT + BOTTOM, rounding = -rib_rounding, edges = [BOTTOM+FRONT, BOTTOM+BACK])
        edge_profile([TOP+FRONT, TOP+BACK])
        mask2d_roundover(r = rib_rounding);
}

module ribs() {
    down(housing_thickness - bottom_thickness + epsilon) {
        // Top edge to support ribs
        rib([supports[0][0], -epsilon], supports[0]);
        rib([supports[1][0], -epsilon], supports[1]);
        rib([supports[2][0], -epsilon], supports[2]);
        rib([supports[3][0], -epsilon], supports[3]);

        // Upper horizontal rib
        rib([-epsilon, supports[0][1]], [pcb_width + epsilon, supports[0][1]]);

        // Center ribs
        rib(supports[0], supports[4]);
        rib(supports[1], supports[4]);
        rib(supports[1], [(supports[4][0] + supports[5][0]) / 2, supports[4][1]]);
        rib(supports[1], supports[5]);
        rib(supports[2], supports[5]);
        rib(supports[2], [(supports[5][0] + supports[6][0]) / 2, supports[5][1]]);
        rib(supports[2], supports[6]);
        rib(supports[3], supports[6]);

        // Lower horizontal rib
        rib([-epsilon, supports[4][1]], [pcb_width + epsilon, supports[4][1]]);

        // Bottom edge to support ribs
        rib(supports[4], [supports[4][0], -pcb_height - epsilon]);
        rib([(supports[4][0] + supports[5][0]) / 2, supports[4][1]], [(supports[4][0] + supports[5][0]) / 2, -pcb_height - epsilon]);
        rib(supports[5], [supports[5][0], -pcb_height - epsilon]);
        rib([(supports[5][0] + supports[6][0]) / 2, supports[5][1]], [(supports[5][0] + supports[6][0]) / 2, -pcb_height - epsilon]);
        rib(supports[6], [supports[6][0], -pcb_height - epsilon]);

        // USB reinforcement ribs
        usb_rib_x = (usb_a[0][0] + usb_a[1][0]) / 2;
        usb_rib_delta = (usb_a[0][0] - usb_rib_x) * 2;
        rib([usb_rib_x, -epsilon], [usb_rib_x, supports[0][1]]);
        rib([usb_rib_x + usb_rib_delta, -epsilon], [usb_rib_x + usb_rib_delta, supports[0][1]]);
        rib([usb_rib_x - usb_rib_delta, -epsilon], [usb_rib_x - usb_rib_delta, supports[0][1]]);

        // JTAG reinforcement rib
        jtag_rib_x = jtag[0] * 2 - supports[2][0];
        rib([jtag_rib_x, -epsilon], [jtag_rib_x, supports[0][1]]);
    }
}

/************************************************/

module drillings() {
    for (i = supports) {
        translate(i) screw_hole(screw_type, thread = true, bevel2 = true, anchor = TOP);
    }
}

/************************************************/

module screws() {
    for (i = supports) {
        translate([i[0], i[1], -2.1]) screw(screw_type, head = "button", drive = "torx");
    }
}

/************************************************/

difference() {
    union() {
        housing();
        supports();
        ribs();
    }
    drillings();
}

//#import("clavier.stl");
//#import("clavier-pcb.stl");

//color("lightblue") screws();
