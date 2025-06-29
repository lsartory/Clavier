-- Clavier | USB_HID.vhd
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

entity USB_HID is
    generic (
        REPORT_DESCRIPTOR:  usb_byte_array_t;
        MAX_EP0_PACKET_LEN: positive;
        EP_IN_ID:           positive;
        EP_OUT_ID:          positive
    );
    port (
        CLK_48MHz:   in  std_logic;
        CLRn:        in  std_logic := '1';

        EP_INPUT:    in  usb_ep_input_signals_t;
        EP_OUTPUT:   out usb_ep_output_signals_t;

        REPORT_DATA: in  usb_byte_array_t
    );
end entity USB_HID;

--------------------------------------------------

architecture USB_HID_arch of USB_HID is
    -- Descriptor ROM signals
    signal descriptor_data: usb_byte_t;
    signal descriptor_addr: unsigned(natural(ceil(log2(real(REPORT_DESCRIPTOR'length)))) - 1 downto 0);

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
    signal control_state: control_state_t;

    -- Setup signals
    signal setup:              usb_setup_packet_t;
    signal setup_byte_counter: unsigned(3 downto 0);

    -- Output signals
    signal packet_len:      unsigned(10 downto 0);
    signal data:            usb_byte_t;
    signal send_descriptor: std_logic;
    signal descriptor_base: unsigned(descriptor_addr'range);

    -- Report data
    signal prev_report_data: usb_byte_array_t(REPORT_DATA'range);
    signal report_addr:      unsigned(6 downto 0);
begin

    -- Descriptor ROM process
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            descriptor_data <= (others => '0');
            if CLRn = '1' then
                descriptor_data <= REPORT_DESCRIPTOR(to_integer(descriptor_addr));
            end if;
        end if;
    end process;

    -- Main process
    process (CLK_48MHz)
        variable rx_data_packet_prev: std_logic;

        variable wValueHigh: unsigned(7 downto 0);
    begin
        if rising_edge(CLK_48MHz) then
            wValueHigh := unsigned(setup.wValue(15 downto 8));

            EP_OUTPUT.tx_ack    <= '0';
            EP_OUTPUT.tx_nak    <= '0';
            EP_OUTPUT.tx_enable <= '0';
            EP_OUTPUT.tx_data   <= (others => '0');

            -- Start the control state machine when a setup packet is received
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
                            when "00000" => control_state <= idle;

                            -- Interface request
                            when "00001" =>
                                case setup.bmRequestType(6 downto 5) is
                                    -- Standard request
                                    when "00" =>
                                        case setup.bRequest is
                                            -- Get_Descriptor
                                            when x"06" =>
                                                case wValueHigh is
                                                    when x"22" =>
                                                        -- Report descriptor
                                                        descriptor_base <= (others => '0');
                                                        if REPORT_DESCRIPTOR'length < unsigned(setup.wLength) then
                                                            setup.wLength <= usb_word_t(to_unsigned(REPORT_DESCRIPTOR'length, setup.wLength'length));
                                                        end if;
                                                        send_descriptor <= '1';

                                                    when others =>
                                                        -- Unknown descriptor type
                                                        control_state <= idle;
                                                end case;

                                            when others => control_state <= idle;
                                        end case;

                                    -- Class request
                                    when "01" =>
                                        case setup.bRequest is
                                            -- Get_Report
                                            when x"01" =>
                                                -- TODO: Get_Report
                                                data <= (others => '0');

                                            -- Get_Idle
                                            when x"02" =>
                                                -- TODO: Get_Idle
                                                data <= (others => '0');

                                            -- Set_Idle
                                            when x"0A" => null;

                                            when others => EP_OUTPUT.tx_enable <= '0';
                                        end case;

                                    -- Vendor request
                                    when "10" => control_state <= idle;

                                    -- Reserved
                                    when others => control_state <= idle;
                                end case;

                            -- Endpoint request
                            when "00010" => control_state <= idle;

                            -- Other request
                            when "00011" => control_state <= idle;

                            -- Reserved
                            when others => control_state <= idle;
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
                        descriptor_base <= descriptor_base + MAX_EP0_PACKET_LEN;
                        if unsigned(setup.wLength) > MAX_EP0_PACKET_LEN then
                            setup.wLength <= usb_word_t(unsigned(setup.wLength) - MAX_EP0_PACKET_LEN);
                        else
                            control_state <= receive_status;
                        end if;
                    end if;

                    -- Compute next packet length
                    packet_len <= to_unsigned(MAX_EP0_PACKET_LEN, packet_len'length);
                    if unsigned(setup.wLength) < MAX_EP0_PACKET_LEN then
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
                        when "00000" => EP_OUTPUT.tx_enable <= '0';

                        -- Interface request
                        when "00001" =>
                            case setup.bmRequestType(6 downto 5) is
                                -- Standard request
                                when "00" => EP_OUTPUT.tx_enable <= '0';

                                -- Class request
                                when "01" =>
                                    case setup.bRequest is
                                        -- Set_Idle
                                        when x"0A" => null; -- TODO: actually set idle

                                        when others => EP_OUTPUT.tx_enable <= '0';
                                    end case;

                                -- Vendor request
                                when "10" => EP_OUTPUT.tx_enable <= '0';

                                -- Reserved
                                when others => EP_OUTPUT.tx_enable <= '0';
                            end case;

                        -- Endpoint request
                        when "00010" => EP_OUTPUT.tx_enable <= '0';

                        -- Other request
                        when "00011" => EP_OUTPUT.tx_enable <= '0';

                        -- Reserved
                        when others => EP_OUTPUT.tx_enable <= '0';
                    end case;

                    -- Mark the exchange as complete
                    control_state <= idle;
            end case;

            -- Disable when other endpoints are being addressed
            if EP_INPUT.endpoint /= 0 then
                control_state <= idle;
            end if;

            -- Input interrupts handling
            if EP_INPUT.endpoint = EP_IN_ID and EP_INPUT.token = token_in and EP_INPUT.start_trans = '1' then
                -- TODO: retransmit until acknowledged instead of only once
                if REPORT_DATA /= prev_report_data then
                    prev_report_data <= REPORT_DATA;
                    packet_len       <= to_unsigned(REPORT_DATA'length, packet_len'length);
                else
                    EP_OUTPUT.tx_nak <= '1';
                end if;
            end if;
            if control_state = idle and packet_len > 0 then
                EP_OUTPUT.tx_enable <= '1';
                EP_OUTPUT.tx_data   <= prev_report_data(to_integer(report_addr));
                if EP_INPUT.tx_read = '1' then
                    packet_len  <= packet_len - 1;
                    report_addr <= report_addr + 1;
                end if;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                control_state       <= idle;
                descriptor_addr     <= (others => '0');
                packet_len          <= (others => '0');
                prev_report_data    <= (others => (others => '0'));
                EP_OUTPUT.tx_enable <= '0';
                EP_OUTPUT.tx_data   <= (others => '0');
            end if;

            rx_data_packet_prev := EP_INPUT.rx_data_packet;
        end if;
    end process;

end USB_HID_arch;
