-- Clavier | Keymap.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.usb_types.all;

--------------------------------------------------

package keymap is
    function keys_to_usb_report(keys: std_logic_vector; report_data: usb_byte_array_t) return usb_byte_array_t;
end package;

--------------------------------------------------

package body keymap is
    function keys_to_usb_report(keys: std_logic_vector; report_data: usb_byte_array_t) return usb_byte_array_t is
        variable ret: usb_byte_array_t(report_data'range) := (others => (others => '0'));
        variable key_code: natural;

        type keymap_array_t is array(natural range <>) of natural;
        constant keymap_array: keymap_array_t(0 to keys'high - keys'low) := (
              0 => 16#04#, -- KEY_A
              1 => 16#34#, -- KEY_APOSTROPHE
              2 => 16#2E#, -- KEY_EQUAL
              3 => 16#E2#, -- KEY_LEFTALT
              4 => 16#E6#, -- KEY_RIGHTALT
              5 => 16#05#, -- KEY_B
              6 => 16#2A#, -- KEY_BACKSPACE
              7 => 16#06#, -- KEY_C
              8 => 16#35#, -- KEY_GRAVE
              9 => 16#36#, -- KEY_COMMA
             10 => 16#39#, -- KEY_CAPSLOCK
             11 => 16#07#, -- KEY_D
             12 => 16#4C#, -- KEY_DELETE
             13 => 16#37#, -- KEY_DOT
             14 => 16#51#, -- KEY_DOWN
             15 => 16#08#, -- KEY_E
             16 => 16#4D#, -- KEY_END
             17 => 16#29#, -- KEY_ESC
             18 => 16#2D#, -- KEY_MINUS
             19 => 16#09#, -- KEY_F
             20 => 16#3A#, -- KEY_F1
             21 => 16#3B#, -- KEY_F2
             22 => 16#3C#, -- KEY_F3
             23 => 16#3D#, -- KEY_F4
             24 => 16#3E#, -- KEY_F5
             25 => 16#3F#, -- KEY_F6
             26 => 16#40#, -- KEY_F7
             27 => 16#41#, -- KEY_F8
             28 => 16#42#, -- KEY_F9
             29 => 16#43#, -- KEY_F10
             30 => 16#44#, -- KEY_F11
             31 => 16#45#, -- KEY_F12
             32 => 16#0A#, -- KEY_G
             33 => 16#0B#, -- KEY_H
             34 => 16#32#, -- KEY_BACKSLASH
             35 => 16#4A#, -- KEY_HOME
             36 => 16#0C#, -- KEY_I
             37 => 16#49#, -- KEY_INSERT
             38 => 16#0D#, -- KEY_J
             39 => 16#0E#, -- KEY_K
             40 => 16#0F#, -- KEY_L
             41 => 16#E0#, -- KEY_LEFTCTRL
             42 => 16#E3#, -- KEY_LEFTMETA
             43 => 16#E1#, -- KEY_LEFTSHIFT
             44 => 16#50#, -- KEY_LEFT
             45 => 16#F9#, -- KEY_COFFEE
             46 => 16#64#, -- KEY_102ND
             47 => 16#10#, -- KEY_M
             48 => 16#65#, -- KEY_COMPOSE
             49 => 16#38#, -- KEY_SLASH
             50 => 16#11#, -- KEY_N
             51 => 16#12#, -- KEY_O
             52 => 16#33#, -- KEY_SEMICOLON
             53 => 16#13#, -- KEY_P
             54 => 16#48#, -- KEY_PAUSE
             55 => 16#4E#, -- KEY_PAGEDOWN
             56 => 16#4B#, -- KEY_PAGEUP
             57 => 16#30#, -- KEY_RIGHTBRACE
             58 => 16#46#, -- KEY_SYSRQ
             59 => 16#14#, -- KEY_Q
             60 => 16#15#, -- KEY_R
             61 => 16#E4#, -- KEY_RIGHTCTRL
             62 => 16#E7#, -- KEY_RIGHTMETA
             63 => 16#E5#, -- KEY_RIGHTSHIFT
             64 => 16#4F#, -- KEY_RIGHT
             65 => 16#28#, -- KEY_ENTER
             66 => 16#16#, -- KEY_S
             67 => 16#47#, -- KEY_SCROLLLOCK
             68 => 16#2C#, -- KEY_SPACE
             69 => 16#17#, -- KEY_T
             70 => 16#2B#, -- KEY_TAB
             71 => 16#18#, -- KEY_U
             72 => 16#2F#, -- KEY_LEFTBRACE
             73 => 16#52#, -- KEY_UP
             74 => 16#19#, -- KEY_V
             75 => 16#1A#, -- KEY_W
             76 => 16#1B#, -- KEY_X
             77 => 16#1D#, -- KEY_Z
             78 => 16#1C#, -- KEY_Y
             79 => 16#27#, -- KEY_0
             80 => 16#1E#, -- KEY_1
             81 => 16#1F#, -- KEY_2
             82 => 16#20#, -- KEY_3
             83 => 16#21#, -- KEY_4
             84 => 16#22#, -- KEY_5
             85 => 16#23#, -- KEY_6
             86 => 16#24#, -- KEY_7
             87 => 16#25#, -- KEY_8
             88 => 16#26#, -- KEY_9
             89 => 16#63#, -- KEY_KPDOT
             90 => 16#56#, -- KEY_KPMINUS
             91 => 16#53#, -- KEY_NUMLOCK
             92 => 16#57#, -- KEY_KPPLUS
             93 => 16#58#, -- KEY_KPENTER
             94 => 16#54#, -- KEY_KPSLASH
             95 => 16#55#, -- KEY_KPASTERISK
             96 => 16#62#, -- KEY_KP0
             97 => 16#59#, -- KEY_KP1
             98 => 16#5A#, -- KEY_KP2
             99 => 16#5B#, -- KEY_KP3
            100 => 16#5C#, -- KEY_KP4
            101 => 16#5D#, -- KEY_KP5
            102 => 16#5E#, -- KEY_KP6
            103 => 16#5F#, -- KEY_KP7
            104 => 16#60#, -- KEY_KP8
            105 => 16#61#  -- KEY_KP9
        );
    begin
        ret(ret'low) := x"01"; -- Report ID

        for i in 0 to keys'high - keys'low loop
            if keys(keys'low + i) = '1' then
                key_code := keymap_array(i);
                if key_code /= 0 then
                    ret(ret'low + (key_code - 4) / 8 + 1)((key_code - 4) mod 8) := '1';
                end if;
            end if;
        end loop;

        return ret;
    end function;
end package body;
