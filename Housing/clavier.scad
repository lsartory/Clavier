// Clavier | clavier.scad
// Copyright (c) 2025 L. Sartory
// SPDX-License-Identifier: CERN-OHL-P-2.0

/************************************************/

//import("clavier.stl");
//import("clavier-pcb.stl");

/************************************************/

$fa = 1;
$fs = $preview ? 2 : 0.1;
epsilon = 0.1;

/************************************************/

board_width = 431.5;
board_height = 125.5;
board_thickness = 1.6;
board_corner = 5.0;

/************************************************/

module rounded_rect(w, h, t, c) {
    hull() {
        translate([c, -c, 0])
            cylinder(h = t, r = c);
        translate([w - c, -c, 0])
            cylinder(h = t, r = c);
        translate([w - c, -h + c, 0])
            cylinder(h = t, r = c);
        translate([c, -h + c, 0])
            cylinder(h = t, r = c);
    }
}

/************************************************/

housing_thickness = 11.5;
bottom_thickness = 2.5;
border_width = 1.5;
ledge_width = 1.0;
bottom_offset = 5.0;
gap = 0.4;

difference() {
    hull() {
        translate([-border_width - gap, border_width + gap, 0])
            rounded_rect(board_width + 2 * (border_width + gap), board_height + 2 * (border_width + gap), board_thickness, board_corner + border_width + gap);
        translate([-border_width - gap, border_width + gap, -housing_thickness])
            rounded_rect(board_width + 2 * (border_width + gap), board_height + bottom_offset + 2 * (border_width + gap), epsilon, board_corner + border_width + gap);
    }
    translate([-gap, gap, 0])
        rounded_rect(board_width + 2 * gap, board_height + 2 * gap, board_thickness + epsilon, board_corner + gap);
    translate([ledge_width, -ledge_width, -housing_thickness + bottom_thickness])
        rounded_rect(board_width - 2 * ledge_width, board_height - 2 * ledge_width, housing_thickness, board_corner - ledge_width);
}

/************************************************/

translate([11.5, -23.75, 0])
    cylinder(5, 1, 1);
translate([11.5+123.5, -23.75, 0])
    cylinder(5, 1, 1);
translate([11.5+123.5+142.5, -23.75, 0])
    cylinder(5, 1, 1);
translate([11.5+123.5+142.5+142.5, -23.75, 0])
    cylinder(5, 1, 1);

translate([25.75, -104.5, 0])
    cylinder(5, 1, 1);
translate([25.75+190, -104.5, 0])
    cylinder(5, 1, 1);
translate([25.75+190+175.75, -104.5, 0])
    cylinder(5, 1, 1);
