-- Clavier | Clavier.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--------------------------------------------------

entity Clavier is
    port (
        CLK_12MHz:   in    std_logic;

        USB_DN:      inout std_logic;
        USB_DP:      inout std_logic;
        USB_DP_PULL: out   std_logic
    );
end entity Clavier;

--------------------------------------------------

architecture Clavier_arch of Clavier is
    -- Common signals
    signal clrn:       std_logic;
    signal pll_clk:    std_logic;
    signal pll_locked: std_logic;

    -- USB signals
    signal usb_oe:             std_logic;
    signal usb_dn_out:         std_logic;
    signal usb_dp_out:         std_logic;
    signal usb_dp_pull_enable: std_logic;
begin

    -- PLL for the USB controller
    pll: entity work.PLL
        port map
        (
            INPUT_CLK  => CLK_12MHz,
            OUTPUT_CLK => pll_clk,
            PLL_LOCKED => pll_locked
        );
    pll_cdc: entity work.VectorCDC
        port map (
            TARGET_CLK => pll_clk,
            INPUT(0)   => pll_locked,
            OUTPUT(0)  => clrn
        );

    usb_dev: entity work.USB_Device
        port map (
            CLK_48MHz   => pll_clk,
            CLRn        => clrn,

            USB_OE      => usb_oe,
            USB_DN_IN   => USB_DN,
            USB_DP_IN   => USB_DP,
            USB_DN_OUT  => usb_dn_out,
            USB_DP_OUT  => usb_dp_out,
            USB_DN_PULL => open,
            USB_DP_PULL => usb_dp_pull_enable,

            FRAME_START => open
        );
    USB_DN      <= usb_dn_out when usb_oe = '1' else 'Z';
    USB_DP      <= usb_dp_out when usb_oe = '1' else 'Z';
    USB_DP_PULL <= '1' when usb_dp_pull_enable = '1' else 'Z';

end Clavier_arch;
