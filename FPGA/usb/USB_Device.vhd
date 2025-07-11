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
        CLK_48MHz:      in  std_logic;
        CLRn:           in  std_logic := '1';

        USB_OE:         out std_logic;
        USB_DN_IN:      in  std_logic;
        USB_DP_IN:      in  std_logic;
        USB_DN_OUT:     out std_logic;
        USB_DP_OUT:     out std_logic;
        USB_DN_PULL:    out std_logic;
        USB_DP_PULL:    out std_logic;

        DEVICE_ADDRESS: in  usb_dev_addr_t;

        EP_INPUT:       out usb_ep_input_signals_t;
        EP_OUTPUTS:     in  usb_ep_output_signals_array_t;

        FRAME_START:    out std_logic;

        DEBUG_TX:       out std_logic
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
    signal token_endpoint:      usb_ep_addr_t;
    signal token_crc_shift_reg: usb_byte_t;
    signal token_crc_counter:   unsigned(3 downto 0);
    signal token_crc5:          std_logic_vector(4 downto 0);
    signal token_start_trans:   std_logic;

    -- Data packet decoder signals
    signal rx_data_start:        std_logic;
    signal rx_data_end:          std_logic;
    signal rx_data_parity:       std_logic;
    signal rx_crc_shift_reg:     usb_byte_t;
    signal rx_crc_counter:       unsigned(3 downto 0);
    signal rx_crc16:             std_logic_vector(15 downto 0);
    signal rx_data_packet:       std_logic;
    signal rx_data_packet_valid: std_logic;
    signal tx_ack:               std_logic;
    signal tx_nak:               std_logic;

    -- Data packet transmitter signals
    type tx_state_t is (
        idle,
        data_header,
        payload,
        crc_1,
        crc_2,
        wait_ack,
        wait_done
    );
    signal tx_state:         tx_state_t;
    signal tx_endpoint:      usb_ep_addr_t;
    signal tx_data_parity:   std_logic;
    signal tx_crc_shift_reg: usb_byte_t;
    signal tx_crc_counter:   unsigned(3 downto 0);
    signal tx_crc16:         std_logic_vector(15 downto 0);
begin
    -- PHY block
    usb_phy: entity work.USB_PHY
        generic map (
            FULL_SPEED => FULL_SPEED
        )
        port map (
            CLK_48MHz  => clk_48MHz,
            CLRn       => clrn,

            USB_OE     => USB_OE,
            USB_DN_IN  => USB_DN_IN,
            USB_DP_IN  => USB_DP_IN,
            USB_DN_OUT => USB_DN_OUT,
            USB_DP_OUT => USB_DP_OUT,

            RX_ACTIVE  => rx_active,
            RX_DATA    => rx_data,
            RX_VALID   => rx_valid,
            RX_EOP     => rx_eop,

            RX_ERROR   => rx_error,
            RX_SUSPEND => rx_suspend,
            RX_RESET   => rx_reset,

            TX_ACTIVE  => open,
            TX_ENABLE  => tx_enable,
            TX_DATA    => tx_data,
            TX_READ    => tx_read,

            DEBUG_TX   => DEBUG_TX
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
            token_start_trans <= '0';
            FRAME_START       <= '0';

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
                            elsif unsigned(token_shift_reg(10 downto 4)) = DEVICE_ADDRESS then
                                case token_shift_reg(3 downto 0) is
                                    when "0001" => token_type <= token_out;
                                    when "1001" => token_type <= token_in;
                                    when "1101" => token_type <= token_setup;
                                    when others => token_type <= token_unknown;
                                end case;
                                token_endpoint    <= usb_ep_addr_t(token_shift_reg(14 downto 11));
                                token_start_trans <= '1';
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
                token_start_trans   <= '0';
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
                    rx_data_start  <= '1';

                when payload =>
                    -- Check the packet identifier
                    if rx_data_start = '1' then
                        if (rx_data_parity = '0' and rx_pid = "0011")
                        or (rx_data_parity = '1' and rx_pid = "1011")
                        then
                            rx_data_packet <= '1';
                            rx_crc16       <= (others => '1');
                        end if;
                    elsif rx_data_packet = '1' and rx_valid = '1' then
                        rx_crc_shift_reg <= rx_data;
                        rx_crc_counter   <= to_unsigned(8, rx_crc_counter'length);
                    end if;
                    rx_data_start <= '0';

                when eop =>
                    -- Wait for the end of the current packet
                    if rx_data_packet = '1' then
                        rx_data_end <= '1';
                    end if;

                when others => null;
            end case;

            -- Compute CRC16
            if rx_crc_counter > 0 then
                rx_crc_counter   <= rx_crc_counter - 1;
                rx_crc_shift_reg <= '0' & rx_crc_shift_reg(rx_crc_shift_reg'high downto rx_crc_shift_reg'low + 1);
                rx_crc16         <= '0' & rx_crc16(rx_crc16'high downto rx_crc16'low + 1);
                rx_crc16(0)      <= rx_crc16(1)  xor rx_crc16(0) xor rx_crc_shift_reg(rx_crc_shift_reg'low);
                rx_crc16(13)     <= rx_crc16(14) xor rx_crc16(0) xor rx_crc_shift_reg(rx_crc_shift_reg'low);
                rx_crc16(15)     <= rx_crc16(0)  xor rx_crc_shift_reg(rx_crc_shift_reg'low);
            end if;

            -- Wait for the CRC computation to be complete
            if rx_data_end = '1' and rx_crc_counter = 0 then
                rx_data_end    <= '0';
                rx_data_packet <= '0';
                if rx_crc16 = "1011000000000001" then
                    rx_data_parity       <= not rx_data_parity;
                    rx_data_packet_valid <= '1';
                    tx_ack               <= '1';
                else
                    tx_nak <= '1';
                end if;
            end if;

            -- Reset data parity, if necessary
            case token_type is
                when token_setup =>
                    -- Setup tokens are always followed by a DATA0 packet
                    rx_data_parity <= '0';
                when token_in =>
                    -- Status is always signaled with a DATA1 packet
                    rx_data_parity <= '1';
                when others => null;
            end case;

            -- Handle ACK/NAK packets from endpoints
            for i in EP_OUTPUTS'range loop
                if EP_OUTPUTS(i).tx_ack = '1' then
                    tx_ack <= '1';
                elsif EP_OUTPUTS(i).tx_nak = '1' then
                    tx_nak <= '1';
                end if;
            end loop;

            -- Synchronous reset
            if CLRn = '0' then
                rx_data_start        <= '0';
                rx_data_end          <= '0';
                rx_data_parity       <= '0';
                rx_data_packet       <= '0';
                rx_data_packet_valid <= '0';
            end if;
        end if;
    end process;

    -- Data packet transmitter
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            case tx_state is
                when idle =>
                    -- Wait until something needs to be transmitted
                    tx_enable <= '0';
                    tx_crc16  <= (others => '1');
                    if tx_ack = '1' then
                        -- Send an ACK
                        tx_enable <= '1';
                        tx_data   <= x"D2";
                        tx_state  <= wait_done;
                    elsif tx_nak = '1' then
                        -- Send a NAK
                        tx_enable <= '1';
                        tx_data   <= x"5A";
                        tx_state  <= wait_done;
                    else
                        -- Prepare sending endpoint data
                        for i in EP_OUTPUTS'range loop
                            if EP_OUTPUTS(i).tx_enable = '1' then
                                tx_endpoint <= to_unsigned(i, tx_endpoint'length);
                                tx_state    <= data_header;
                                exit;
                            end if;
                        end loop;
                    end if;

                when data_header =>
                    -- Send the data header
                    tx_enable <= '1';
                    if tx_data_parity = '0' then
                        -- DATA0
                        tx_data <= x"C3";
                    else
                        -- DATA1
                        tx_data <= x"4B";
                    end if;
                    if tx_read = '1' then
                        tx_state <= payload;
                    end if;

                when payload =>
                    -- Send endpoint data
                    if EP_OUTPUTS(to_integer(tx_endpoint)).tx_enable = '1' then
                        tx_enable <= '1';
                        tx_data   <= EP_OUTPUTS(to_integer(tx_endpoint)).tx_data;
                    else
                        tx_state <= crc_1;
                    end if;
                    if tx_read = '1' then
                        tx_crc_shift_reg <= tx_data;
                        tx_crc_counter   <= to_unsigned(8, tx_crc_counter'length);
                    end if;

                -- Send CRC16
                when crc_1 =>
                    if tx_crc_counter = 0 then
                        tx_data <= not tx_crc16(7 downto 0);
                    end if;
                    if tx_read = '1' then
                        tx_state <= crc_2;
                    end if;
                when crc_2 =>
                    tx_data <= not tx_crc16(15 downto 8);
                    if tx_read = '1' then
                        tx_enable <= '0';
                        tx_state  <= wait_ack;
                    end if;

                -- Wait for the packet to be acknowledged
                when wait_ack =>
                    if rx_ack = '1' then
                        tx_data_parity <= not tx_data_parity;
                        tx_state       <= idle;
                    end if;
                    if token_start_trans = '1' then
                        -- No ACK received, retransmit
                        tx_state <= idle;
                    end if;

                when wait_done =>
                    -- Wait until the transmitter is not busy anymore
                    if tx_read = '1' then
                        tx_enable <= '0';
                        tx_state  <= idle;
                    end if;
            end case;

            -- Compute CRC16
            if tx_crc_counter > 0 then
                tx_crc_counter   <= tx_crc_counter - 1;
                tx_crc_shift_reg <= '0' & tx_crc_shift_reg(tx_crc_shift_reg'high downto tx_crc_shift_reg'low + 1);
                tx_crc16         <= '0' & tx_crc16(tx_crc16'high downto tx_crc16'low + 1);
                tx_crc16(0)      <= tx_crc16(1)  xor tx_crc16(0) xor tx_crc_shift_reg(tx_crc_shift_reg'low);
                tx_crc16(13)     <= tx_crc16(14) xor tx_crc16(0) xor tx_crc_shift_reg(tx_crc_shift_reg'low);
                tx_crc16(15)     <= tx_crc16(0)  xor tx_crc_shift_reg(tx_crc_shift_reg'low);
            end if;

            -- Setup tokens are always answered by a DATA1 packet
            if token_type = token_setup then
                tx_data_parity <= '1';
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                tx_data_parity <= '0';
                tx_enable      <= '0';
                tx_state       <= idle;
            end if;
        end if;
    end process;

    -- Endpoint communication signals
    EP_INPUT.token       <= token_type;
    EP_INPUT.endpoint    <= token_endpoint;
    EP_INPUT.start_trans <= token_start_trans;

    EP_INPUT.rx_reset             <= rx_reset;
    EP_INPUT.rx_data_packet       <= rx_data_packet;
    EP_INPUT.rx_data_packet_valid <= rx_data_packet_valid;
    EP_INPUT.rx_data              <= rx_data;
    EP_INPUT.rx_data_valid        <= rx_valid;
    EP_INPUT.rx_ack               <= rx_ack;

    EP_INPUT.tx_read <= tx_read when tx_state = payload else '0';

end USB_Device_arch;
