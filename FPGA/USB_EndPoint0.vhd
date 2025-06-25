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
    constant MAX_PACKET_LEN: positive := 8;

    -- Descriptor ROM signals
    -- TODO: change this to a RAM to allow setting the serial number from an external source
    constant DESCRIPTOR_ROM: usb_byte_array_t := to_byte_array(DESCRIPTORS);
    signal descriptor_data: usb_byte_t;
    signal descriptor_addr: unsigned(natural(ceil(log2(real(DESCRIPTOR_ROM'length)))) - 1 downto 0);

    -- Setup handler signals
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

    -- Transaction handler signals
    signal send_len:        unsigned(15 downto 0);
    signal packet_len:      unsigned(14 downto 0);
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

    -- Setup packet handler
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            -- Deserialize the setup packet
            if EP_INPUT.rx_data_packet = '1' and EP_INPUT.token = token_setup and EP_INPUT.endpoint = 0 then
                setup.valid <= '0';

                if EP_INPUT.rx_data_valid = '1' then
                    setup_byte_counter <= setup_byte_counter + 1;

                    case to_integer(setup_byte_counter) is
                        when 0 => setup.valid <= '0';
                                  setup.bmRequestType        <= EP_INPUT.rx_data;
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
            elsif EP_INPUT.rx_data_packet_valid = '1' and EP_INPUT.token = token_setup and EP_INPUT.endpoint = 0 then
                setup.valid <= '1';
            else
                setup_byte_counter <= (others => '0');
            end if;

            -- Synchronous reset
            if CLRn = '0' or EP_INPUT.rx_reset = '1' then
                setup.valid        <= '0';
                setup_byte_counter <= (others => '0');
            end if;
        end if;
    end process;

    -- Control transfer exchange handler
    process (CLK_48MHz)
        variable wValueHigh: unsigned(7 downto 0);
        variable wValueLow:  unsigned(7 downto 0);
    begin
        if rising_edge(CLK_48MHz) then
            wValueHigh := unsigned(setup.wValue(15 downto 8));
            wValueLow  := unsigned(setup.wValue( 7 downto 0));

            EP_OUTPUT.tx_enable <= '0';
            EP_OUTPUT.tx_data   <= (others => '0');

            -- Handle new transaction
            if setup.valid = '1' and EP_INPUT.start_trans = '1' and EP_INPUT.endpoint = 0 then
                -- Input transaction
                if setup.bmRequestType(7) = '1' and EP_INPUT.token = token_in then
                    -- Send remaining data, if any
                    packet_len <= to_unsigned(MAX_PACKET_LEN, packet_len'length);
                    if send_len > 0 and send_len < MAX_PACKET_LEN then
                        packet_len <= resize(send_len, packet_len'length);
                    end if;
                    descriptor_addr <= descriptor_base;

                    -- Check what kind of answer is expected
                    if send_len = 0 and setup.bmRequestType = x"80" then
                        case setup.bRequest is
                            -- GET_STATUS
                            when x"00" =>
                                null; -- TODO

                            -- GET_DESCRIPTOR
                            when x"06" =>
                                case wValueHigh is
                                    when x"01" =>
                                        -- Device descriptor
                                        descriptor_base <= resize(DESCRIPTORS.device.header.rom_offset, descriptor_base'length);
                                        descriptor_addr <= resize(DESCRIPTORS.device.header.rom_offset, descriptor_addr'length);
                                        send_len        <= resize(unsigned(DESCRIPTORS.device.header.bLength), send_len'length);
                                        if unsigned(setup.wLength) < unsigned(DESCRIPTORS.device.header.bLength) then
                                            send_len <= resize(unsigned(setup.wLength), send_len'length);
                                        end if;

                                    when x"02" =>
                                        -- Configuration descriptor
                                        if wValueLow < unsigned(DESCRIPTORS.device.bNumConfigurations) then
                                            descriptor_base <= resize(DESCRIPTORS.device.configurations(to_integer(wValueLow)).header.rom_offset, descriptor_base'length);
                                            descriptor_addr <= resize(DESCRIPTORS.device.configurations(to_integer(wValueLow)).header.rom_offset, descriptor_addr'length);
                                            send_len        <= resize(unsigned(DESCRIPTORS.device.configurations(to_integer(wValueLow)).wTotalLength), send_len'length);
                                            if unsigned(setup.wLength) < unsigned(DESCRIPTORS.device.configurations(to_integer(wValueLow)).wTotalLength) then
                                                send_len <= resize(unsigned(setup.wLength), send_len'length);
                                            end if;
                                        else
                                            send_len            <= (others => '0');
                                            EP_OUTPUT.tx_enable <= '1';
                                        end if;

                                    when x"03" =>
                                        -- String descriptor
                                        if wValueLow < get_string_count(DESCRIPTORS.strings) then
                                            descriptor_base <= resize(DESCRIPTORS.strings(to_integer(wValueLow)).header.rom_offset, descriptor_base'length);
                                            descriptor_addr <= resize(DESCRIPTORS.strings(to_integer(wValueLow)).header.rom_offset, descriptor_addr'length);
                                            send_len        <= resize(unsigned(DESCRIPTORS.strings(to_integer(wValueLow)).header.bLength), send_len'length);
                                            if unsigned(setup.wLength) < unsigned(DESCRIPTORS.strings(to_integer(wValueLow)).header.bLength) then
                                                -- TODO: check this (and others that are similar)
                                                send_len <= resize(unsigned(setup.wLength), send_len'length);
                                            end if;
                                        else
                                            send_len            <= (others => '0');
                                            EP_OUTPUT.tx_enable <= '1';
                                        end if;

                                    when others => null;
                                end case;

                            -- GET_CONFIGURATION
                            when x"08" =>
                                null; -- TODO

                            when others => null;
                        end case;
                    end if;
                end if;
                if setup.bmRequestType(7) = '1' and EP_INPUT.token = token_out then
                    -- TODO: receive status packet?
                end if;

                -- Output transaction
                if setup.bmRequestType(7) = '0' and EP_INPUT.token = token_out then
                    -- TODO: handle incoming data
                end if;
                if setup.bmRequestType(7) = '0' and EP_INPUT.token = token_in then
                    -- Send status packet
                    EP_OUTPUT.tx_enable <= '1';

                    -- Apply the request
                    case setup.bRequest is
                        -- CLEAR_FEATURE
                        when x"01" =>
                            null; -- TODO

                        -- SET_FEATURE
                        when x"03" =>
                            null; -- TODO

                        -- SET_ADDRESS
                        when x"05" =>
                            DEVICE_ADDRESS <= usb_dev_addr_t(setup.wValue(DEVICE_ADDRESS'range));

                        -- SET_CONFIGURATION
                        when x"09" =>
                            null; -- TODO

                        when others => null;
                    end case;

                    -- Mark transfer as complete
                    send_len   <= (others => '0');
                    packet_len <= (others => '0');
                end if;
            end if;

            -- Transmit the response
            -- TODO: implement responses other than descriptors
            if send_len > 0 and packet_len > 0 then
                EP_OUTPUT.tx_enable <= '1';
                EP_OUTPUT.tx_data   <= descriptor_data;

                if packet_len > send_len then
                    packet_len <= resize(send_len, packet_len'length);
                end if;
                if EP_INPUT.tx_read = '1' then
                    descriptor_addr <= descriptor_addr + 1;
                    packet_len      <= packet_len - 1;
                end if;
            end if;

            -- Handle ACK packets
            if EP_INPUT.rx_ack = '1' then
                descriptor_base <= descriptor_base + MAX_PACKET_LEN;
                if send_len >= MAX_PACKET_LEN then
                    send_len <= send_len - MAX_PACKET_LEN;
                else
                    send_len <= (others => '0');
                end if;
            end if;

            -- Reset send length when a new transfer starts
            -- TODO: replace all this by a FSM
            if EP_INPUT.token = token_setup then
                send_len <= (others => '0');
            end if;

            -- Synchronous reset
            if CLRn = '0' or EP_INPUT.rx_reset = '1' then
                descriptor_base     <= (others => '0');
                descriptor_addr     <= (others => '0');
                send_len            <= (others => '0');
                EP_OUTPUT.tx_enable <= '0';
                EP_OUTPUT.tx_data   <= (others => '0');
                DEVICE_ADDRESS      <= (others => '0');
            end if;
        end if;
    end process;

end USB_EndPoint0_arch;
