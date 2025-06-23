-- Clavier | USB_Device.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.usb_types.all;

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
        USB_DP_PULL: out std_logic;

        FRAME_START: out std_logic
    );
end entity USB_Device;

--------------------------------------------------

architecture USB_Device_arch of USB_Device is
    -- PHY signals
    signal rx_active:  std_logic;
    signal rx_data:    usb_byte_t;
    signal rx_valid:   std_logic;
    signal rx_eop:     std_logic;
    signal rx_error:   std_logic;
    signal rx_suspend: std_logic;
    signal rx_reset:   std_logic;
    signal tx_enable:  std_logic;
    signal tx_data:    usb_byte_t;
    signal tx_read:    std_logic;

    -- State handling signals
    type usb_state_t is (
        detached,
        connect,
        idle,
        pid,
        payload,
        skip_to_eop,
        eop,
        suspend,
        reset
    );
    signal usb_state: usb_state_t;
    signal rx_pid: std_logic_vector(3 downto 0);

    -- Handshake packet decoder signals
    signal rx_ack: std_logic;
    --signal rx_nak: std_logic;

    -- Token packet decoder signals
    type token_decoder_state_t is (
        idle,
        load_data_1,
        load_data_2,
        decode_data,
        wait_eop
    );
    signal token_decoder_state: token_decoder_state_t;
    signal token_shift_reg:     std_logic_vector(19 downto 0);
    signal token_type:          usb_token_t;
    signal token_endpoint:      usb_endpoint_t;
    signal token_crc_shift_reg: usb_byte_t;
    signal token_crc_counter:   unsigned(3 downto 0);
    signal token_crc5:          std_logic_vector(4 downto 0);

    -- Data packet decoder signals
    signal data_start:           std_logic;
    signal data_end:             std_logic;
    signal data_parity:          std_logic;
    signal data_crc_shift_reg:   usb_byte_t;
    signal data_crc_counter:     unsigned(3 downto 0);
    signal data_crc16:           std_logic_vector(15 downto 0);
    signal rx_data_packet:       std_logic;
    signal rx_data_packet_valid: std_logic;
    signal tx_ack: std_logic;
    signal tx_nak: std_logic;

    -- Data packet transmitter signals
    signal tx_wait_read: std_logic;

    -- Endpoint 0 signals
    signal device_address: usb_dev_addr_t;
begin
    -- PHY block
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
            RX_RESET    => rx_reset,

            TX_ACTIVE   => open,
            TX_ENABLE   => tx_enable,
            TX_DATA     => tx_data,
            TX_READ     => tx_read
        );

    -- State handling process
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            case usb_state is
                when detached =>
                    -- Keep all lines deactivated
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
                    -- Wait for the start of a packet
                    if rx_active = '1' then
                        usb_state <= pid;
                    end if;

                when pid =>
                    -- Get the packet identifier
                    if rx_valid = '1' then
                        rx_pid    <= rx_data(3 downto 0);
                        usb_state <= payload;
                        -- Verify the PID
                        for i in 0 to 3 loop
                            if rx_data(i) = rx_data(i + 4) then
                                rx_pid    <= (others => '0');
                                usb_state <= idle;
                            end if;
                        end loop;
                    end if;

                when payload | skip_to_eop =>
                    -- Detect the end of the current packet
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
                        usb_state <= connect;
                    end if;
            end case;

            -- Handle special receiver events
            if rx_reset = '1' then
                usb_state <= reset;
            elsif rx_error = '1' then
                usb_state <= skip_to_eop;
            elsif rx_suspend = '1' then
                usb_state <= suspend;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                usb_state <= detached;
            end if;
        end if;
    end process;

    -- Handshake packet decoder
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            rx_ack <= '0';
            --rx_nak <= '0';
            if CLRn = '1' and usb_state = eop then
                case rx_pid is
                    when "0010" => rx_ack <= '1';
                    --when "1010" => rx_nak <= '1'; -- Normally unreachable
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    -- Token packet decoder
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            FRAME_START <= '0';

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
                    -- Decode the received data
                    if token_crc_counter = 0 then
                        if token_crc5 = "00110" then
                            if token_shift_reg(3 downto 0) = "0101" then
                                FRAME_START <= '1';
                            elsif unsigned(token_shift_reg(10 downto 4)) = device_address then
                                case token_shift_reg(3 downto 0) is
                                    when "0001" => token_type <= token_out;
                                    when "1001" => token_type <= token_in;
                                    when "1101" => token_type <= token_setup;
                                    when others => token_type <= token_unknown;
                                end case;
                                token_endpoint <= usb_endpoint_t(token_shift_reg(14 downto 11));
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
            if usb_state = pid then
                token_decoder_state <= idle;
            end if;

            -- Compute CRC5
            if token_crc_counter > 0 then
                token_crc_counter   <= token_crc_counter - 1;
                token_crc_shift_reg <= '0' & token_crc_shift_reg(token_crc_shift_reg'high downto token_crc_shift_reg'low + 1);
                token_crc5          <= '0' & token_crc5(token_crc5'high downto token_crc5'low + 1);
                token_crc5(2)       <= token_crc5(3) xor token_crc5(0) xor token_crc_shift_reg(token_crc_shift_reg'low);
                token_crc5(4)       <= token_crc5(0) xor token_crc_shift_reg(token_crc_shift_reg'low);
            end if;

            -- Reset the transaction state after an acknowledge
            if rx_ack = '1' or tx_ack = '1' then
                token_type <= token_none;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                token_type          <= token_none;
                token_endpoint      <= (others => '0');
                token_decoder_state <= idle;
                FRAME_START         <= '0';
            end if;
        end if;
    end process;

    -- Data packet decoder
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            rx_data_packet_valid <= '0';
            tx_ack               <= '0';
            tx_nak               <= '0';

            case usb_state is
                when pid =>
                    -- Wait for the beginning of a packet
                    rx_data_packet <= '0';
                    data_start     <= '1';

                when payload =>
                    -- Check the packet identifier
                    if data_start = '1' then
                        if (data_parity = '0' and rx_pid = "0011")
                        or (data_parity = '1' and rx_pid = "1011")
                        then
                            rx_data_packet <= '1';
                            data_crc16     <= (others => '1');
                        end if;
                    elsif rx_data_packet = '1' and rx_valid = '1' then
                        data_crc_shift_reg <= rx_data;
                        data_crc_counter   <= to_unsigned(8, data_crc_counter'length);
                    end if;
                    data_start <= '0';

                when eop =>
                    -- Wait for the end of the current packet
                    if rx_data_packet = '1' then
                        data_end <= '1';
                    end if;

                when others => null;
            end case;

            -- Compute CRC16
            if data_crc_counter > 0 then
                data_crc_counter   <= data_crc_counter - 1;
                data_crc_shift_reg <= '0' & data_crc_shift_reg(data_crc_shift_reg'high downto data_crc_shift_reg'low + 1);
                data_crc16         <= '0' & data_crc16(data_crc16'high downto data_crc16'low + 1);
                data_crc16(0)      <= data_crc16(1)  xor data_crc16(0) xor data_crc_shift_reg(data_crc_shift_reg'low);
                data_crc16(13)     <= data_crc16(14) xor data_crc16(0) xor data_crc_shift_reg(data_crc_shift_reg'low);
                data_crc16(15)     <= data_crc16(0)  xor data_crc_shift_reg(data_crc_shift_reg'low);
            end if;

            -- Wait for the CRC computation to be complete
            if data_end = '1' and data_crc_counter = 0 then
                data_end       <= '0';
                rx_data_packet <= '0';
                if data_crc16 = "1011000000000001" then
                    data_parity          <= not data_parity;
                    rx_data_packet_valid <= '1';
                    tx_ack               <= '1';
                else
                    tx_nak <= '1';
                end if;
            end if;

            -- Setup tokens are always followed by a DATA0 packet
            if token_type = token_setup then
                data_parity <= '0';
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                data_start           <= '0';
                data_end             <= '0';
                data_parity          <= '0';
                rx_data_packet       <= '0';
                rx_data_packet_valid <= '0';
            end if;
        end if;
    end process;

    -- Data packet transmitter
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            tx_enable <= '0';

            -- Check if an ACK or NAK needs to be sent
            if tx_ack = '1' then
                tx_enable    <= '1';
                tx_data      <= x"D2";
                tx_wait_read <= '1';
            elsif tx_nak = '1' then
                tx_enable    <= '1';
                tx_data      <= x"5A";
                tx_wait_read <= '1';
            end if;

            -- Send the second byte of the ACK or NAK packet
            if tx_wait_read = '1' then
                tx_enable <= '1';
                if tx_read = '1' then
                    tx_wait_read <= '0';
                end if;
            end if;

            -- TODO: send data with CRC16

            -- Synchronous reset
            if CLRn = '0' then
                tx_enable    <= '0';
                tx_wait_read <= '0';
            end if;
        end if;
    end process;

    -- Endpoint 0
    usb_ep0: entity work.USB_EndPoint0
        port map (
            CLK_48MHz            => CLK_48MHz,
            CLRn                 => CLRn,

            TOKEN                => token_type,
            ENDPOINT             => token_endpoint,

            RX_DATA_PACKET       => rx_data_packet,
            RX_DATA_PACKET_VALID => rx_data_packet_valid,
            RX_DATA              => rx_data,
            RX_DATA_VALID        => rx_valid,
            RX_EOP               => rx_eop,

            DEVICE_ADDRESS       => device_address
        );
end USB_Device_arch;
