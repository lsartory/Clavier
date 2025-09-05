-- Clavier | Utils.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--------------------------------------------------

package utils is
    -- Returns the bit width required to fit a given natural number
    function unsigned_bit_width(x: natural) return natural;

    -- Converts a time into clock ticks for a frequency given in MHz
    function time_to_ticks(t: time; c: real) return natural;
end package;

--------------------------------------------------

package body utils is
    -- Returns the bit width required to fit a given natural number
    function unsigned_bit_width(x: natural) return natural is
    begin
        if x <= 2 then
            return 1;
        end if;
        return natural(ceil(log2(real(x))));
    end function;

    -- Converts a time into clock ticks for a frequency given in MHz
    function time_to_ticks(t: time; c: real) return natural is
    begin
        return integer(c * real(t / 1 us));
    end function;
end package body;
