-- Clavier | USB_Device.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity USB_Device is
    port (
        CLK_96MHz:   in    std_logic;
        CLRn:        in    std_logic := '1';

        USB_DN:      inout std_logic;
        USB_DP:      inout std_logic;
        USB_DP_PULL: out   std_logic
    );
end entity USB_Device;

--------------------------------------------------

architecture USB_Device_arch of USB_Device is
begin
    process (CLK_96MHz)
    begin
        if rising_edge(CLK_96MHz) then
            -- Enable the D+ pull-up resistor
            USB_DP_PULL <= '1';

            -- Synchronous reset
            if CLRn = '0' then
                USB_DN      <= 'Z';
                USB_DP      <= 'Z';
                USB_DP_PULL <= 'Z';
            end if;
        end if;
    end process;
end USB_Device_arch;
