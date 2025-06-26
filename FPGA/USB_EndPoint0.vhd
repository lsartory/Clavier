-- Clavier | USB_EndPoint0.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.usb_types.all;
use work.usb_descriptors.all;

--------------------------------------------------

entity USB_EndPoint0 is
    generic (
        DESCRIPTORS: usb_descriptors_t
    );
    port (
        CLK_48MHz:      in  std_logic;
        CLRn:           in  std_logic := '1';

        EP_INPUT:       in  usb_ep_input_signals_t;
        EP_OUTPUT:      out usb_ep_output_signals_t;

        DEVICE_ADDRESS: out usb_dev_addr_t
    );
end entity USB_EndPoint0;

--------------------------------------------------

architecture USB_EndPoint0_arch of USB_EndPoint0 is
    constant MAX_PACKET_LEN: positive := to_integer(unsigned(DESCRIPTORS.device.bMaxPacketSize0));

    -- Descriptor ROM signals
    -- TODO: change this to a RAM to allow setting the serial number from an external source
    constant DESCRIPTOR_ROM: usb_byte_array_t := to_byte_array(DESCRIPTORS);
    signal descriptor_data: usb_byte_t;
    signal descriptor_addr: unsigned(natural(ceil(log2(real(DESCRIPTOR_ROM'length)))) - 1 downto 0);

    -- Control transfer signals
    type control_state_t is (
        idle,
        receive_setup,

        wait_send_data,
        send_data,
        receive_status,

        wait_receive_data,
        receive_data,
        send_status
    );
    signal control_state:  control_state_t;
    signal current_config: usb_byte_t;

    -- Setup signals
    type setup_packet_t is record
        valid:         std_logic;
        bmRequestType: usb_byte_t;
        bRequest:      usb_byte_t;
        wValue:        usb_word_t;
        wIndex:        usb_word_t;
        wLength:       usb_word_t;
    end record;
    signal setup:              setup_packet_t;
    signal setup_byte_counter: unsigned(3 downto 0);

    -- Output signals
    signal packet_len:      unsigned(10 downto 0);
    signal data:            usb_byte_t;
    signal send_descriptor: std_logic;
    signal descriptor_base: unsigned(descriptor_addr'range);
begin

    -- Descriptor ROM process
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            descriptor_data <= (others => '0');
            if CLRn = '1' then
                descriptor_data <= DESCRIPTOR_ROM(to_integer(descriptor_addr));
            end if;
        end if;
    end process;

    -- Control transfer handler
    process (CLK_48MHz)
        variable rx_data_packet_prev: std_logic;

        variable wValueHigh: unsigned(7 downto 0);
        variable wValueLow:  unsigned(7 downto 0);
    begin
        if rising_edge(CLK_48MHz) then
            wValueHigh := unsigned(setup.wValue(15 downto 8));
            wValueLow  := unsigned(setup.wValue( 7 downto 0));

            EP_OUTPUT.tx_enable <= '0';
            EP_OUTPUT.tx_data   <= (others => '0');

            -- Start the state machine when a setup packet is received
            if EP_INPUT.rx_data_packet = '1' and rx_data_packet_prev = '0' and EP_INPUT.token = token_setup then
                setup_byte_counter <= (others => '0');
                control_state      <= receive_setup;
            end if;

            -- Control state machine
            case control_state is
                when idle => null;

                when receive_setup =>
                    -- Receive the setup packet
                    if EP_INPUT.rx_data_valid = '1' then
                        setup_byte_counter <= setup_byte_counter + 1;

                        case to_integer(setup_byte_counter) is
                            when 0 => setup.bmRequestType        <= EP_INPUT.rx_data;
                            when 1 => setup.bRequest             <= EP_INPUT.rx_data;
                            when 2 => setup.wValue( 7 downto 0)  <= EP_INPUT.rx_data;
                            when 3 => setup.wValue(15 downto 8)  <= EP_INPUT.rx_data;
                            when 4 => setup.wIndex( 7 downto 0)  <= EP_INPUT.rx_data;
                            when 5 => setup.wIndex(15 downto 8)  <= EP_INPUT.rx_data;
                            when 6 => setup.wLength( 7 downto 0) <= EP_INPUT.rx_data;
                            when 7 => setup.wLength(15 downto 8) <= EP_INPUT.rx_data;
                            when others =>
                                -- Ignore extra bytes
                                setup_byte_counter <= setup_byte_counter;
                        end case;
                    end if;

                    -- Switch to the next step
                    if EP_INPUT.rx_data_packet_valid = '1' then
                        control_state <= wait_receive_data;
                        if setup.bmRequestType(setup.bmRequestType'high) = '1' then
                            control_state <= wait_send_data;
                        end if;
                        send_descriptor <= '0';

                        -- Check what kind of answer is expected
                        case setup.bmRequestType(4 downto 0) is
                            -- Device request
                            when "00000" =>
                                case setup.bmRequestType(6 downto 5) is
                                    -- Standard request
                                    when "00" =>
                                        case setup.bRequest is
                                            -- GET_STATUS
                                            when x"00" =>
                                                data <= x"00"; -- TODO: return actual status

                                            -- GET_DESCRIPTOR
                                            when x"06" =>
                                                case wValueHigh is
                                                    when x"01" =>
                                                        -- Device descriptor
                                                        descriptor_base <= resize(DESCRIPTORS.device.header.rom_offset, descriptor_base'length);
                                                        if unsigned(DESCRIPTORS.device.header.bLength) < unsigned(setup.wLength) then
                                                            setup.wLength <= usb_word_t(resize(unsigned(DESCRIPTORS.device.header.bLength), setup.wLength'length));
                                                        end if;
                                                        send_descriptor <= '1';

                                                    when x"02" =>
                                                        -- Configuration descriptor
                                                        if wValueLow < unsigned(DESCRIPTORS.device.bNumConfigurations) then
                                                            descriptor_base <= resize(DESCRIPTORS.device.configurations(to_integer(wValueLow)).header.rom_offset, descriptor_base'length);
                                                            if unsigned(DESCRIPTORS.device.configurations(to_integer(wValueLow)).wTotalLength) < unsigned(setup.wLength) then
                                                                setup.wLength <= usb_word_t(resize(unsigned(DESCRIPTORS.device.configurations(to_integer(wValueLow)).wTotalLength), setup.wLength'length));
                                                            end if;
                                                            send_descriptor <= '1';
                                                        else
                                                            setup.wLength <= (others => '0');
                                                        end if;

                                                    when x"03" =>
                                                        -- String descriptor
                                                        if wValueLow < get_string_count(DESCRIPTORS.strings) then
                                                            descriptor_base <= resize(DESCRIPTORS.strings(to_integer(wValueLow)).header.rom_offset, descriptor_base'length);
                                                            if unsigned(DESCRIPTORS.strings(to_integer(wValueLow)).header.bLength) < unsigned(setup.wLength) then
                                                                setup.wLength <= usb_word_t(resize(unsigned(DESCRIPTORS.strings(to_integer(wValueLow)).header.bLength), setup.wLength'length));
                                                            end if;
                                                            send_descriptor <= '1';
                                                        else
                                                            setup.wLength <= (others => '0');
                                                        end if;

                                                    when others =>
                                                        -- Unknown descriptor type
                                                        control_state <= idle;
                                                end case;

                                            -- GET_CONFIGURATION
                                            when x"08" =>
                                                data <= current_config;

                                            when others => null;
                                        end case;

                                    -- Class request
                                    when "01" => null;

                                    -- Vendor request
                                    when "10" => null;

                                    -- Reserved
                                    when others => null;
                                end case;

                            -- Interface request
                            when "00001" => null;

                            -- Endpoint request
                            when "00010" => null;

                            -- Other request
                            when "00011" => null;

                            -- Reserved
                            when others => null;
                        end case;
                    end if;

                when wait_send_data =>
                    -- Wait for the host to request data
                    if EP_INPUT.start_trans = '1' then
                        case EP_INPUT.token is
                            when token_in    => control_state <= send_data;
                            when token_out   => control_state <= receive_status;
                            when token_setup => control_state <= receive_setup;
                            when others      => control_state <= idle;
                        end case;
                    end if;

                    -- Handle ACK packets
                    if EP_INPUT.rx_ack = '1' then
                        descriptor_base <= descriptor_base + MAX_PACKET_LEN;
                        if unsigned(setup.wLength) > MAX_PACKET_LEN then
                            setup.wLength <= usb_word_t(unsigned(setup.wLength) - MAX_PACKET_LEN);
                        else
                            control_state <= receive_status;
                        end if;
                    end if;

                    -- Compute next packet length
                    packet_len <= to_unsigned(MAX_PACKET_LEN, packet_len'length);
                    if unsigned(setup.wLength) < MAX_PACKET_LEN then
                        packet_len <= resize(unsigned(setup.wLength), packet_len'length);
                    end if;
                    descriptor_addr <= descriptor_base;

                when send_data =>
                    -- Send data
                    EP_OUTPUT.tx_enable <= '1';
                    EP_OUTPUT.tx_data   <= data;
                    if send_descriptor = '1' then
                        EP_OUTPUT.tx_data <= descriptor_data;
                    end if;

                    -- Check if more data is available
                    if EP_INPUT.tx_read = '1' then
                        descriptor_addr <= descriptor_addr + 1;
                        packet_len      <= packet_len - 1;
                    end if;
                    if packet_len = 0 then
                        control_state <= wait_send_data;
                    end if;

                when receive_status =>
                    -- Mark the exchange as complete
                    if EP_INPUT.start_trans = '1' and EP_INPUT.token = token_in then
                        control_state <= idle;
                    end if;

                when wait_receive_data =>
                    -- Wait for the host to start sending data
                    if EP_INPUT.start_trans = '1' then
                        case EP_INPUT.token is
                            when token_out   => control_state <= receive_data;
                            when token_in    => control_state <= send_status;
                            when token_setup => control_state <= receive_setup;
                            when others      => control_state <= idle;
                        end case;
                    end if;

                when receive_data =>
                    -- We don't actually need to receive data,
                    -- but if we did, it would take place here...
                    control_state <= wait_receive_data;

                when send_status =>
                    -- Send the status packet
                    EP_OUTPUT.tx_enable <= '1';

                    -- Commit the request
                    case setup.bmRequestType(4 downto 0) is
                        -- Device request
                        when "00000" =>
                            case setup.bmRequestType(6 downto 5) is
                                -- Standard request
                                when "00" =>
                                    case setup.bRequest is
                                        -- CLEAR_FEATURE
                                        when x"01" =>
                                            null; -- TODO: useful for remote wakeup

                                        -- SET_FEATURE
                                        when x"03" =>
                                            null; -- TODO: useful for remote wakeup

                                        -- SET_ADDRESS
                                        when x"05" =>
                                            DEVICE_ADDRESS <= usb_dev_addr_t(setup.wValue(DEVICE_ADDRESS'range));

                                        -- SET_CONFIGURATION
                                        when x"09" =>
                                            current_config <= usb_byte_t(wValueLow);

                                        when others => null;
                                    end case;

                                -- Class request
                                when "01" => null;

                                -- Vendor request
                                when "10" => null;

                                -- Reserved
                                when others => null;
                            end case;

                        -- Interface request
                        when "00001" => null;

                        -- Endpoint request
                        when "00010" => null;

                        -- Other request
                        when "00011" => null;

                        -- Reserved
                        when others => null;
                    end case;

                    -- Mark the exchange as complete
                    control_state <= idle;
            end case;

            -- Disable when other endpoints are being addressed
            if EP_INPUT.endpoint /= 0 then
                control_state <= idle;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                control_state       <= idle;
                descriptor_addr     <= (others => '0');
                current_config      <= (others => '0');
                EP_OUTPUT.tx_enable <= '0';
                EP_OUTPUT.tx_data   <= (others => '0');
                DEVICE_ADDRESS      <= (others => '0');
            end if;

            rx_data_packet_prev := EP_INPUT.rx_data_packet;
        end if;
    end process;

end USB_EndPoint0_arch;
