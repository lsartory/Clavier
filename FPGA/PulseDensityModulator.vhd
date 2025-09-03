-- Clavier | PulseDensityModulator.vhd
-- Copyright (c) 2021-2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity PulseDensityModulator is
    port (
        CLK    : in  std_logic;
        CLRn   : in  std_logic;
        ENA    : in  std_logic := '1';

        INPUT  : in  unsigned;
        OUTPUT : out std_logic
    );
end entity PulseDensityModulator;

--------------------------------------------------

architecture PulseDensityModulator_arch of PulseDensityModulator is
    signal sigma : unsigned(INPUT'high + 4 downto INPUT'low);
begin

    -- First order sigma delta modulator
    process (CLK)
        variable delta     : unsigned(sigma'high downto sigma'low) := (others => '0');
        variable clrn_prev : std_logic := '1';
    begin
        if rising_edge(CLK) then
            delta := (delta'high downto INPUT'high + 1 => '0') & (INPUT'high downto INPUT'low => sigma(sigma'high));
            if ENA = '1' then
                sigma <= (sigma - delta + INPUT);
            end if;

            if clrn_prev = '1' then
                OUTPUT <= sigma(sigma'high);
            end if;
            if CLRn = '0' then
                sigma  <= '1' & (sigma'high - 1 downto sigma'low => '0');
                OUTPUT <= '0';
            end if;

            clrn_prev := CLRn;
        end if;
    end process;

end PulseDensityModulator_arch;
