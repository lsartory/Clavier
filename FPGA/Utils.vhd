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
    -- Frequency unit definition
    type Frequency is range 0 to Integer'high
        units
            Hz;
            kHz = 1000 Hz;
            MHz = 1000 kHz;
            GHz = 1000 MHz;
        end units;

    -- Converts a delay length into clock ticks for a given frequency
    function delay_to_ticks(t: delay_length; c: frequency) return natural;

    -- Returns the bit width required to fit a given natural number
    function unsigned_bit_width(x: natural) return natural;
end package;

--------------------------------------------------

package body utils is
    -- Converts a delay length into clock ticks for a given frequency
    function delay_to_ticks(t: delay_length; c: frequency) return natural is
    begin
        return integer(real(c / 1 Hz) * real(t / 1 fs) * 1.0e-15);
    end function;

    -- Returns the bit width required to fit a given natural number
    function unsigned_bit_width(x: natural) return natural is
    begin
        if x <= 2 then
            return 1;
        end if;
        return natural(ceil(log2(real(x))));
    end function;
end package body;
