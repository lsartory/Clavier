-- Clavier | VectorCDC.vhd
-- Copyright (c) 2015-2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--------------------------------------------------

    -- WARNING: This entity does not ensure data integrity for buses!
    --          For this, an additional handshake mechanism is required.

entity VectorCDC is
    generic (
        LATCH_COUNT: positive := 3
    );
    port (
        TARGET_CLK: in  std_logic;
        INPUT:      in  std_logic_vector;
        OUTPUT:     out std_logic_vector
    );
end entity VectorCDC;

--------------------------------------------------

architecture VectorCDC_arch of VectorCDC is
    type latch_array is array(natural range <>) of std_logic_vector(INPUT'high downto INPUT'low);
    signal input_latch: latch_array(LATCH_COUNT - 1 downto 0);
begin

    -- Vector clock domain crossing
    process (TARGET_CLK)
    begin
        if rising_edge(TARGET_CLK) then
            for i in input_latch'high downto input_latch'low + 1 loop
                input_latch(i) <= input_latch(i - 1);
            end loop;
            input_latch(input_latch'low) <= INPUT;
        end if;
    end process;
    OUTPUT <= input_latch(input_latch'high);

end VectorCDC_arch;
