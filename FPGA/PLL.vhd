-- Clavier | PLL.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--------------------------------------------------

entity PLL is
    port (
        INPUT_CLK:  in  std_logic;
        OUTPUT_CLK: out std_logic;
        PLL_LOCKED: out std_logic
    );
end PLL;

--------------------------------------------------

architecture PLL_arch of PLL is

    -- Clock feedback
    signal clk_out: std_logic;

    -- PLL attributes
    attribute FREQUENCY_PIN_CLKOP: string;
    attribute FREQUENCY_PIN_CLKOP of pll_inst: label is "48.000000";
    attribute FREQUENCY_PIN_CLKI: string;
    attribute FREQUENCY_PIN_CLKI of pll_inst: label is "12.000000";
    attribute ICP_CURRENT: string;
    attribute ICP_CURRENT of pll_inst: label is "11";
    attribute LPF_RESISTOR: string;
    attribute LPF_RESISTOR of pll_inst: label is "8";
    attribute NGD_DRC_MASK: integer;
    attribute NGD_DRC_MASK of PLL_arch: architecture is 1;

    component EHXPLLL is
        generic (
            CLKI_DIV:         integer := 1;
            CLKFB_DIV:        integer := 1;
            CLKOP_DIV:        integer := 8;
            CLKOS_DIV:        integer := 8;
            CLKOS2_DIV:       integer := 8;
            CLKOS3_DIV:       integer := 8;
            CLKOP_ENABLE:     string  := "ENABLED";
            CLKOS_ENABLE:     string  := "DISABLED";
            CLKOS2_ENABLE:    string  := "DISABLED";
            CLKOS3_ENABLE:    string  := "DISABLED";
            CLKOP_CPHASE:     integer := 0;
            CLKOS_CPHASE:     integer := 0;
            CLKOS2_CPHASE:    integer := 0;
            CLKOS3_CPHASE:    integer := 0;
            CLKOP_FPHASE:     integer := 0;
            CLKOS_FPHASE:     integer := 0;
            CLKOS2_FPHASE:    integer := 0;
            CLKOS3_FPHASE:    integer := 0;
            FEEDBK_PATH:      string  := "CLKOP";
            CLKOP_TRIM_POL:   string  := "RISING";
            CLKOP_TRIM_DELAY: integer := 0;
            CLKOS_TRIM_POL:   string  := "RISING";
            CLKOS_TRIM_DELAY: integer := 0;
            OUTDIVIDER_MUXA:  string  := "DIVA";
            OUTDIVIDER_MUXB:  string  := "DIVB";
            OUTDIVIDER_MUXC:  string  := "DIVC";
            OUTDIVIDER_MUXD:  string  := "DIVD";
            PLL_LOCK_MODE:    integer := 0;
            PLL_LOCK_DELAY:   integer := 200;
            STDBY_ENABLE:     string  := "DISABLED";
            REFIN_RESET:      string  := "DISABLED";
            SYNC_ENABLE:      string  := "DISABLED";
            INT_LOCK_STICKY:  string  := "ENABLED";
            DPHASE_SOURCE:    string  := "DISABLED";
            PLLRST_ENA:       string  := "DISABLED";
            INTFB_WAKE:       string  := "DISABLED"
        );
        port (
            CLKI:         in  std_logic;
            CLKFB:        in  std_logic;
            PHASESEL1:    in  std_logic;
            PHASESEL0:    in  std_logic;
            PHASEDIR:     in  std_logic;
            PHASESTEP:    in  std_logic;
            PHASELOADREG: in  std_logic;
            STDBY:        in  std_logic;
            PLLWAKESYNC:  in  std_logic;
            RST:          in  std_logic;
            ENCLKOP:      in  std_logic;
            ENCLKOS:      in  std_logic;
            ENCLKOS2:     in  std_logic;
            ENCLKOS3:     in  std_logic;
            CLKOP:        out std_logic;
            CLKOS:        out std_logic;
            CLKOS2:       out std_logic;
            CLKOS3:       out std_logic;
            LOCK:         out std_logic;
            INTLOCK:      out std_logic;
            REFCLK:       out std_logic;
            CLKINTFB:     out std_logic
        );
    end component;

begin

    pll_inst: EHXPLLL
        generic map (
            CLKI_DIV         => 1,
            CLKFB_DIV        => 8,
            CLKOP_DIV        => 12,
            CLKOS_DIV        => 1,
            CLKOS2_DIV       => 1,
            CLKOS3_DIV       => 1,
            CLKOP_ENABLE     => "ENABLED",
            CLKOS_ENABLE     => "DISABLED",
            CLKOS2_ENABLE    => "DISABLED",
            CLKOS3_ENABLE    => "DISABLED",
            CLKOP_CPHASE     => 11,
            CLKOS_CPHASE     => 0,
            CLKOS2_CPHASE    => 0,
            CLKOS3_CPHASE    => 0,
            CLKOP_FPHASE     => 0,
            CLKOS_FPHASE     => 0,
            CLKOS2_FPHASE    => 0,
            CLKOS3_FPHASE    => 0,
            FEEDBK_PATH      => "CLKOP",
            CLKOP_TRIM_POL   => "FALLING",
            CLKOP_TRIM_DELAY => 0,
            CLKOS_TRIM_POL   => "FALLING",
            CLKOS_TRIM_DELAY => 0,
            OUTDIVIDER_MUXA  => "DIVA",
            OUTDIVIDER_MUXB  => "DIVB",
            OUTDIVIDER_MUXC  => "DIVC",
            OUTDIVIDER_MUXD  => "DIVD",
            PLL_LOCK_MODE    => 0,
            PLL_LOCK_DELAY   => 200,
            STDBY_ENABLE     => "DISABLED",
            REFIN_RESET      => "DISABLED",
            SYNC_ENABLE      => "DISABLED",
            INT_LOCK_STICKY  => "ENABLED",
            DPHASE_SOURCE    => "DISABLED",
            PLLRST_ENA       => "DISABLED",
            INTFB_WAKE       => "DISABLED"
        )
        port map (
            CLKI         => INPUT_CLK,
            CLKFB        => clk_out,
            PHASESEL1    => '0',
            PHASESEL0    => '0',
            PHASEDIR     => '0',
            PHASESTEP    => '0',
            PHASELOADREG => '0',
            STDBY        => '0',
            PLLWAKESYNC  => '0',
            RST          => '0',
            ENCLKOP      => '0',
            ENCLKOS      => '0',
            ENCLKOS2     => '0',
            ENCLKOS3     => '0',
            CLKOP        => clk_out,
            CLKOS        => open,
            CLKOS2       => open,
            CLKOS3       => open,
            LOCK         => PLL_LOCKED,
            INTLOCK      => open,
            REFCLK       => open,
            CLKINTFB     => open
        );

    OUTPUT_CLK <= clk_out;

end PLL_arch;
