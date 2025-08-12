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

        // Bottom chamfers
        translate([-border_width - gap, border_width + gap, -housing_thickness])
            chamfer_edge_mask(l = pcb_width + (border_width + gap) * 2, chamfer = housing_chamfer, orient = RIGHT, anchor = BOTTOM);
        translate([-border_width - gap, -pcb_height - bottom_offset - border_width, -housing_thickness])
            chamfer_edge_mask(l = pcb_width + (border_width + gap) * 2, chamfer = housing_chamfer, orient = RIGHT, anchor = BOTTOM);
        translate([-border_width - gap, border_width + gap, -housing_thickness])
            chamfer_edge_mask(l = pcb_height + bottom_offset + (border_width + gap) * 2, chamfer = housing_chamfer, orient = FRONT, anchor = BOTTOM);
        translate([pcb_width + border_width + gap, border_width + gap, -housing_thickness])
            chamfer_edge_mask(l = pcb_height + bottom_offset + (border_width + gap) * 2, chamfer = housing_chamfer, orient = FRONT, anchor = BOTTOM);
        translate([pcb_corner, -pcb_corner, -housing_thickness])
            back_half() left_half() chamfer_cylinder_mask(r = pcb_corner + border_width + gap, chamfer = 1, orient = BOTTOM);
        translate([pcb_width - pcb_corner, -pcb_corner, -housing_thickness])
            back_half() right_half() chamfer_cylinder_mask(r = pcb_corner + border_width + gap, chamfer = 1, orient = BOTTOM);
        translate([pcb_corner, -pcb_height + pcb_corner - bottom_offset, -housing_thickness])
            front_half() left_half() chamfer_cylinder_mask(r = pcb_corner + border_width + gap, chamfer = 1, orient = BOTTOM);
        translate([pcb_width - pcb_corner, -pcb_height + pcb_corner - bottom_offset, -housing_thickness])
            front_half() right_half() chamfer_cylinder_mask(r = pcb_corner + border_width + gap, chamfer = 1, orient = BOTTOM);
    }

    // TODO: USB openings
    // TODO: JTAG opening
    // TODO: Stabilizers openings
}

/************************************************/

screw_type = "M3,9";

mounting_diameter = 7.00;
mounting_base     = 8.00;

supports = [
    [11.50,  -23.75], [135.00,  -23.75], [277.50,  -23.75], [420.00, -23.75],
    [25.75, -104.50], [215.75, -104.50], [391.50, -104.50]
];

module supports() {
    for (i = supports) {
        translate(i) difference() {
            // Support
            cyl(l = housing_thickness - bottom_thickness + epsilon, r = mounting_diameter / 2, rounding1 = -mounting_base, rounding2 = 1.00, anchor = TOP);

            // Threaded hole
            screw_hole(screw_type, thread = true, anchor = TOP);
        }
    }
}

/************************************************/

module screws() {
    for (i = supports) {
        translate([i[0], i[1], -2.1]) screw(screw_type, head = "button", drive = "torx");
    }
}

/************************************************/

union() {
    housing();
    supports();
}

//import("clavier.stl");
//#import("clavier-pcb.stl");

//color("lightblue") screws();
