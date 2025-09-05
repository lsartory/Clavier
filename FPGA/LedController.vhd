-- Clavier | LedController.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils.all;

--------------------------------------------------

entity LedController is
    generic (
        RESET_DELAY: time := 1 sec
    );
	port (
        CLK_48MHz:  in  std_logic;
        CLRn:       in  std_logic := '1';

        LED_STATES: in  std_logic_vector;
        BRIGHTNESS: in  unsigned;

        LEDS:       out std_logic_vector
    );
end entity LedController;

--------------------------------------------------

architecture LedController_arch of LedController is
    -- Frequency generator signals
    signal led_ena: std_logic;

    -- Reset signals
    constant RESET_DELAY_INT: natural := time_to_ticks(RESET_DELAY, 48.000000);
    signal reset_counter: unsigned(unsigned_bit_width(RESET_DELAY_INT) - 1 downto 0);

    -- Startup animation signals
    type led_animation_t is (idle, rise, fall, done);
    type led_animation_array_t is array(natural range <>) of led_animation_t;
    signal led_animation: led_animation_array_t(LEDS'range);

    -- Modulator signals
    type led_value_array_t is array(natural range <>) of unsigned(BRIGHTNESS'range);
    signal led_values: led_value_array_t(LEDS'range);
    signal led_out:    std_logic_vector(LEDS'range);
begin

    -- Modulator frequency generator
    pdm_cs: entity work.ClockScaler
        generic map(
            INPUT_FREQUENCY  => 48.000000,
            OUTPUT_FREQUENCY =>  0.100000 -- 100 kHz
        )
        port map (
            INPUT_CLK    => CLK_48MHz,
            CLRn         => CLRn,
            OUTPUT_CLK   => open,
            OUTPUT_PULSE => led_ena
        );

    -- LED control process
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            -- Refresh the LED modulator values
            if led_ena = '1' then
                for i in led_values'low to led_values'high loop
                    led_values(i) <= (others => '0');
                    case led_animation(i) is
                        when idle =>
                            -- Do nothing
                            null;

                        when rise =>
                            -- Increase the brightness
                            led_values(i) <= led_values(i) + 2;
                            if led_values(i) + 2 < led_values(i) then
                                led_values(i)    <= (others => '1');
                                led_animation(i) <= fall;
                            end if;

                        when fall =>
                            -- Decrease the brightness
                            led_values(i) <= led_values(i) - 2;
                            if led_values(i) - 2 > led_values(i) then
                                led_values(i)    <= (others => '0');
                                led_animation(i) <= done;
                            end if;

                        when done =>
                            -- Normal mode, fixed brightness
                            if LED_STATES(i) = '1' then
                                led_values(i) <= BRIGHTNESS;
                            end if;
                    end case;
                end loop;
            end if;

            -- Animation sequence
            if reset_counter < RESET_DELAY_INT then
                reset_counter <= reset_counter + 1;
            elsif led_animation(2) = idle then
                led_animation(2) <= rise;
            elsif led_animation(2) = fall then
                led_animation(1) <= rise;
                led_animation(3) <= rise;
            end if;
            if led_animation(1) = fall then
                led_animation(0) <= rise;
            end if;
            if led_animation(3) = fall then
                led_animation(4) <= rise;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                reset_counter <= (others => '0');
                led_values    <= (others => (others => '0'));
                led_animation <= (others => idle);
            end if;
        end if;
    end process;

    -- Modulator array
    pdm_gen: for i in LEDS'range generate
    begin
        led_pdm: entity work.PulseDensityModulator
            port map (
                CLK    => CLK_48MHz,
                CLRn   => CLRn,
                ENA    => led_ena,

                INPUT  => led_values(i),
                OUTPUT => led_out(i)
            );
    end generate;
    LEDS <= not led_out;

end LedController_arch;
