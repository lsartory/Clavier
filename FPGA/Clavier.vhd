-- Clavier | Clavier.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--------------------------------------------------

entity Clavier is
    port (
        CLK_12MHz: in std_logic
    );
end entity Clavier;

--------------------------------------------------

architecture Clavier_arch of Clavier is
    -- Common signals
    signal clrn:       std_logic;
    signal pll_clk:    std_logic;
    signal pll_locked: std_logic;
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

end Clavier_arch;
