-- Clavier | ClockScaler.vhd
-- Copyright (c) 2016-2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--------------------------------------------------

entity ClockScaler is
    generic (
        INPUT_FREQUENCY:  real; -- MHz
        OUTPUT_FREQUENCY: real  -- MHz
    );
    port (
        INPUT_CLK:    in  std_logic;
        CLRn:         in  std_logic;
        OUTPUT_CLK:   out std_logic;
        OUTPUT_PULSE: out std_logic
    );
end ClockScaler;

--------------------------------------------------

architecture ClockScaler_arch of ClockScaler is
    signal counter: unsigned(31 downto 0);

    function real_to_unsigned(x : real; size : natural) return unsigned is
        variable tmp:    real := round(x);
        variable result: unsigned(size - 1 downto 0) := (others => '0');
    begin
        for i in result'high downto result'low loop
            if tmp > (2.0 ** i) then
                result(i) := '1';
                tmp := tmp - (2.0 ** i);
            end if;
        end loop;
        return result;
    end;
begin

    -- Scale the input clock to match the requested output frequency
    process (INPUT_CLK)
        variable output_prev: std_logic;
    begin
        if rising_edge(INPUT_CLK) then
            OUTPUT_PULSE <= '0';

            if CLRn = '0' then
                counter <= (others => '0');
            else
                counter <= counter + real_to_unsigned((OUTPUT_FREQUENCY / INPUT_FREQUENCY) * (2.0 ** counter'length), counter'length);
                if counter(counter'high) = '1' and output_prev = '0' then
                    OUTPUT_PULSE <= '1';
                end if;
            end if;

            output_prev := counter(counter'high);
        end if;
    end process;
    OUTPUT_CLK <= counter(counter'high);

end ClockScaler_arch;
