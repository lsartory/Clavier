-- Clavier | Debouncer.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity Debouncer is
	generic (
		FILTER_DURATION: natural := 480_000 -- 10 ms @ 48 MHz
	);
	port (
		CLK_48MHz:     in  std_logic;
        CLRn:          in  std_logic := '1';

		KEY_INPUT:     in  std_logic;
		KEY_DEBOUNCED: out std_logic
	);
end entity Debouncer;

--------------------------------------------------

architecture Debouncer_arch of Debouncer is
	signal key_sync:       std_logic := '0';
	signal key_latched:    std_logic := '0';
	signal filter_counter: unsigned(25 downto 0) := (others => '0');
begin

	-- Key input synchronization
	key_cdc : entity work.VectorCDC
		port map (
			TARGET_CLK => CLK_48MHz,
			INPUT(0)   => KEY_INPUT,
			OUTPUT(0)  => key_sync
		);

	-- Filter process
	process (CLK_48MHz)
	begin
		if rising_edge(CLK_48MHz) then
            -- Simple filter
            if filter_counter /= 0 then
                filter_counter <= filter_counter - 1;
            elsif key_sync /= key_latched then
                key_latched    <= key_sync;
                filter_counter <= to_unsigned(FILTER_DURATION, filter_counter'length);
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                filter_counter <= (others => '0');
                key_latched    <= '0';
            end if;
		end if;
	end process;
    KEY_DEBOUNCED <= key_latched;

end Debouncer_arch;
