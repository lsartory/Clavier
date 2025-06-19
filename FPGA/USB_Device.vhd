-- Clavier | USB_Device.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity USB_Device is
    generic (
        FULL_SPEED: boolean := true
    );
    port (
        CLK_48MHz:   in  std_logic;
        CLRn:        in  std_logic := '1';

        USB_OE:      out std_logic;
        USB_DN_IN:   in  std_logic;
        USB_DP_IN:   in  std_logic;
        USB_DN_OUT:  out std_logic;
        USB_DP_OUT:  out std_logic;
        USB_DN_PULL: out std_logic;
        USB_DP_PULL: out std_logic
    );
end entity USB_Device;

--------------------------------------------------

architecture USB_Device_arch of USB_Device is
    signal rx_active:  std_logic;
    signal rx_data:    std_logic_vector(7 downto 0);
    signal rx_valid:   std_logic;
    signal rx_eop:     std_logic;
    signal rx_error:   std_logic;
    signal rx_suspend: std_logic;
    signal rx_reset:   std_logic;

    type usb_state_t is (
        detached,
        connect,
        idle,
        sync,
        pid,
        payload,
        eop,
        suspend,
        reset
    );
    signal usb_state: usb_state_t;
    signal device_address: unsigned(6 downto 0) := (others => '0'); -- TODO: reset value
    signal rx_pid: std_logic_vector(3 downto 0);

    type token_type_t is (
        token_none,
        token_out,
        token_in,
        token_setup,
        token_unknown
    );
    type token_decoder_state_t is (
        idle,
        load_data_1,
        load_data_2,
        decode_data,
        wait_eop
    );
    signal token_decoder_state: token_decoder_state_t;
    signal token_shift_reg:     std_logic_vector(19 downto 0);
    signal token_type:          token_type_t;
    signal token_endpoint:      std_logic_vector(3 downto 0);
    signal token_crc_shift_reg: std_logic_vector(7 downto 0);
    signal token_crc_counter:   unsigned(3 downto 0);
    signal token_crc5:          std_logic_vector(4 downto 0);
begin
    usb_phy: entity work.USB_PHY
        generic map (
            FULL_SPEED => FULL_SPEED
        )
        port map (
            CLK_48MHz   => clk_48MHz,
            CLRn        => clrn,

            USB_OE      => USB_OE,
            USB_DN_IN   => USB_DN_IN,
            USB_DP_IN   => USB_DP_IN,
            USB_DN_OUT  => USB_DN_OUT,
            USB_DP_OUT  => USB_DP_OUT,

            RX_ACTIVE   => rx_active,
            RX_DATA     => rx_data,
            RX_VALID    => rx_valid,
            RX_EOP      => rx_eop,

            RX_ERROR    => rx_error,
            RX_SUSPEND  => rx_suspend,
            RX_RESET    => rx_reset
        );

    -- State handling process
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            case usb_state is
                when detached =>
                    -- Keep all lines deactivated
                    USB_OE      <= '0';
                    USB_DN_OUT  <= '0';
                    USB_DP_OUT  <= '0';
                    USB_DN_PULL <= '0';
                    USB_DP_PULL <= '0';
                    usb_state   <= connect;

                when connect =>
                    if FULL_SPEED then
                        -- Enable the D+ pull-up resistor
                        USB_DP_PULL <= '1';
                    else -- Low speed
                        -- Enable the D- pull-up resistor
                        USB_DN_PULL <= '1';
                    end if;
                    usb_state <= idle;

                when idle =>
                    -- Detect sync patterns
                    if rx_active = '1' then
                        usb_state <= sync;
                    end if;

                when sync =>
                    -- Wait until synchronization is complete
                    if rx_valid = '1' then
                        usb_state <= idle;
                        if rx_data = x"80" then
                            usb_state <= pid;
                        end if;
                    end if;

                when pid =>
                    -- Get the packet identifier
                    if rx_valid = '1' then
                        usb_state <= payload;
                        rx_pid    <= rx_data(3 downto 0);
                        for i in 0 to 3 loop
                            if rx_data(i) = rx_data(i + 4) then
                                usb_state <= idle;
                            end if;
                        end loop;
                    end if;

                when payload =>
                    -- Detect end of packet
                    if rx_eop = '1' then
                        usb_state <= eop;
                    end if;

                when eop =>
                    -- Wait for the next packet
                    usb_state <= idle;

                when suspend => null;
                    -- Low power mode
                    if rx_suspend = '0' then
                        usb_state <= idle;
                    end if;

                when reset =>
                    -- Host reset
                    if rx_reset = '0' then
                        usb_state <= detached;
                    end if;
            end case;

            -- Handle special receiver events
            if rx_reset = '1' then
                usb_state <= reset;
            elsif rx_error = '1' then
                usb_state <= idle;
            elsif rx_suspend = '1' then
                usb_state <= suspend;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                usb_state <= detached;
            end if;
        end if;
    end process;

    -- Token packet decoder
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            case token_decoder_state is
                when idle =>
                    -- Wait for a new packet
                    if usb_state = payload then
                        token_shift_reg     <= rx_pid & (15 downto 0 => '0');
                        token_crc5          <= (others => '1');
                        token_decoder_state <= load_data_1;
                    end if;

                when load_data_1 =>
                    -- Receive the first byte
                    if rx_valid = '1' then
                        token_shift_reg     <= rx_data & token_shift_reg(token_shift_reg'high downto token_shift_reg'low + 8);
                        token_crc_shift_reg <= rx_data;
                        token_crc_counter   <= to_unsigned(8, token_crc_counter'length);
                        token_decoder_state <= load_data_2;
                    end if;
                when load_data_2 =>
                    -- Receive the second byte
                    if rx_valid = '1' then
                        token_shift_reg     <= rx_data & token_shift_reg(token_shift_reg'high downto token_shift_reg'low + 8);
                        token_crc_shift_reg <= rx_data;
                        token_crc_counter   <= to_unsigned(8, token_crc_counter'length);
                        token_decoder_state <= decode_data;
                    end if;

                when decode_data =>
                    if token_crc_counter = 0 then
                        -- Decode the received data
                        if token_crc5 = "01100" then
                            token_type <= token_none;
                            if unsigned(token_shift_reg(10 downto 4)) = device_address then
                                case token_shift_reg(3 downto 0) is
                                    when "0001" => token_type <= token_out;
                                    when "1001" => token_type <= token_in;
                                    when "1101" => token_type <= token_setup;
                                    when others => token_type <= token_unknown;
                                end case;
                                token_endpoint <= token_shift_reg(14 downto 11);
                            end if;
                        end if;
                        token_decoder_state <= wait_eop;
                    end if;

                when wait_eop =>
                    -- Wait for the end of packet
                    if usb_state = eop or usb_state = idle then
                        token_decoder_state <= idle;
                    end if;
            end case;

            -- Compute CRC5
            if token_crc_counter > 0 then
                token_crc_counter   <= token_crc_counter - 1;
                token_crc_shift_reg <= '0' & token_crc_shift_reg(token_crc_shift_reg'high downto token_crc_shift_reg'low + 1);
                token_crc5(0)       <= token_crc5(4) xor token_crc_shift_reg(token_crc_shift_reg'low);
                token_crc5(1)       <= token_crc5(0);
                token_crc5(2)       <= token_crc5(1) xor token_crc5(4) xor token_crc_shift_reg(token_shift_reg'low);
                token_crc5(3)       <= token_crc5(2);
                token_crc5(4)       <= token_crc5(3);
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                token_type          <= token_none;
                token_endpoint      <= (others => '0');
                token_decoder_state <= idle;
            end if;
        end if;
    end process;
end USB_Device_arch;
