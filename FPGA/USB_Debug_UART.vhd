-- Clavier | USB_Debug_UART.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.usb_types.all;

--------------------------------------------------

entity USB_Debug_UART is
    port (
        CLK_48MHz:  in  std_logic;
        CLRn:       in  std_logic := '1';

        RX_START:   in  std_logic;
        TX_START:   in  std_logic;
        DATA:       in  usb_byte_t;
        DATA_VALID: in  std_logic;
        EOP:        in  std_logic;

        DEBUG_TX:   out std_logic
    );
end entity USB_Debug_UART;

--------------------------------------------------

architecture USB_Debug_UART_arch of USB_Debug_UART is
    -- Baud rate scaler signals
    signal tx_pulse: std_logic;

    -- FIFO signals
    signal fifo:            usb_byte_array_t(0 to 1023);
    signal fifo_data_in:    usb_byte_t;
    signal fifo_data_out:   usb_byte_t;
    signal fifo_write_addr: unsigned(9 downto 0);
    signal fifo_read_addr:  unsigned(9 downto 0);
    signal fifo_write:      std_logic;
    signal fifo_read:       std_logic;
    signal fifo_empty:      std_logic;
    signal fifo_overflow:   std_logic;

    -- Input encoder signals
    signal input_shift_reg: usb_byte_array_t(0 to 8);

    -- UART TX signals
    signal tx_shift_reg:     std_logic_vector(fifo_data_out'length + 1 downto 0);
    signal tx_shift_counter: unsigned(4 downto 0);

    -- Helper functions
    function to_byte_array(s: string; len: positive) return usb_byte_array_t is
        variable ret: usb_byte_array_t(0 to len - 1) := (others => (others => '0'));
    begin
        for i in ret'range loop
            if s'length > 0 and s'low + i <= s'high then
                ret(i) := usb_byte_t(to_unsigned(character'pos(s(s'low + i)), 8));
            end if;
        end loop;
        return ret;
    end function;

    -- Convert an unsigned value into ASCII-coded hexadecimal
    function to_ascii_hex(x: std_logic_vector(3 downto 0)) return usb_byte_t is
    begin
        case to_integer(unsigned(x)) is
            when 16#0# to 16#9# => return usb_byte_t(to_unsigned(character'pos('0'), 8) + unsigned(x));
            when 16#A# to 16#F# => return usb_byte_t(to_unsigned(character'pos('A'), 8) + unsigned(x) - 10);
            when others         => return usb_byte_t(to_unsigned(character'pos('?'), 8));
        end case;
    end function;
begin
    -- Baud rate scaler
    debug_cs: entity work.ClockScaler
        generic map (
            INPUT_FREQUENCY  => 48.000000,
            OUTPUT_FREQUENCY =>  1.000000
        )
        port map (
            INPUT_CLK    => CLK_48MHz,
            CLRn         => CLRn,
            OUTPUT_CLK   => open,
            OUTPUT_PULSE => tx_pulse
        );

    -- Data FIFO process
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            fifo_data_out  <= fifo(to_integer(fifo_read_addr));
            fifo_empty     <= '1';
            fifo_overflow  <= '0';

            -- FIFO empty check
            if fifo_read_addr /= fifo_write_addr then
                fifo_empty <= '0';
            end if;

            -- FIFO write access
            if fifo_write = '1' then
                fifo(to_integer(fifo_write_addr)) <= fifo_data_in;
                if fifo_read = '0' then
                    if fifo_write_addr + 1 = fifo_read_addr then
                        fifo_empty    <= '1';
                        fifo_overflow <= '1';
                    end if;
                end if;
                fifo_write_addr <= fifo_write_addr + 1;
            end if;

            -- FIFO read access
            if fifo_read = '1' and fifo_read_addr /= fifo_write_addr then
                if fifo_read_addr + 1 = fifo_write_addr then
                    fifo_empty <= '1';
                end if;
                fifo_read_addr <= fifo_read_addr + 1;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                fifo_read_addr  <= (others => '0');
                fifo_write_addr <= (others => '0');
                fifo_data_out   <= (others => '0');
                fifo_empty      <= '1';
                fifo_overflow   <= '0';
            end if;
        end if;
    end process;

    -- Input encoder
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            fifo_write <= '0';

            -- Get events
            if fifo_overflow = '1' then
                input_shift_reg <= to_byte_array(LF & "Ovrflw!", input_shift_reg'length);
            elsif RX_START = '1' then
                input_shift_reg <= to_byte_array(LF & "H->D: ", input_shift_reg'length);
            elsif TX_START = '1' then
                input_shift_reg <= to_byte_array(LF & "D->H: ", input_shift_reg'length);
            elsif DATA_VALID = '1' then
                input_shift_reg(0) <= to_ascii_hex(DATA(7 downto 4));
                input_shift_reg(1) <= to_ascii_hex(DATA(3 downto 0));
                input_shift_reg(2) <= usb_byte_t(to_unsigned(character'pos(' '), 8));
            elsif EOP = '1' then
                input_shift_reg <= to_byte_array("EOP", input_shift_reg'length);
            end if;

            -- Save to FIFO
            if input_shift_reg /= to_byte_array("", input_shift_reg'length) then
                fifo_write      <= '1';
                fifo_data_in    <= input_shift_reg(input_shift_reg'low);
                input_shift_reg <= input_shift_reg(input_shift_reg'low + 1 to input_shift_reg'high) & x"00";
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                fifo_write      <= '0';
                input_shift_reg <= to_byte_array(LF & "Reset", input_shift_reg'length);
            end if;
        end if;
    end process;

    -- UART TX process
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            fifo_read <= '0';

            -- Wait for data to be available
            if tx_shift_counter = 0 then
                DEBUG_TX <= '1';
                if fifo_empty = '0' then
                    tx_shift_reg     <= '1' & fifo_data_out & '0';
                    tx_shift_counter <= to_unsigned(tx_shift_reg'length, tx_shift_counter'length);
                    fifo_read        <= '1';
                end if;
            elsif tx_pulse = '1' then
                -- Transmit data
                DEBUG_TX         <= tx_shift_reg(tx_shift_reg'low);
                tx_shift_reg     <= '0' & tx_shift_reg(tx_shift_reg'high downto tx_shift_reg'low + 1);
                tx_shift_counter <= tx_shift_counter - 1;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                fifo_read        <= '0';
                tx_shift_counter <= (others => '0');
                DEBUG_TX         <= '1';
            end if;
        end if;
    end process;
end USB_Debug_UART_arch;
