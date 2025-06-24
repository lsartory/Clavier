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
    -- Descriptor ROM signals
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

    -- Input handler signals
    signal send_len:   unsigned(15 downto 0);
    signal packet_len: unsigned(14 downto 0);
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
            if CLRn = '0' then
                DEVICE_ADDRESS     <= (others => '0');
                setup.valid        <= '0';
                setup_byte_counter <= (others => '0');
            end if;
        end if;
    end process;

    -- Input packet handler
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            EP_OUTPUT.tx_enable <= '0';
            EP_OUTPUT.tx_data   <= (others => '0');

            if setup.valid = '1' and EP_INPUT.rx_eop = '1' and EP_INPUT.token = token_in and EP_INPUT.endpoint = 0 then
                -- A new request was received
                packet_len <= to_unsigned(8, packet_len'length);

                -- Check what kind of answer is expected
                if send_len = 0 and setup.bmRequestType = x"80" then
                    case setup.bRequest is
                        -- GET_STATUS
                        when x"00" =>
                            null; -- TODO

                        -- GET_DESCRIPTOR
                        when x"06" =>
                            case setup.wValue(15 downto 8) is
                                when x"01" =>
                                    -- Device descriptor
                                    descriptor_addr <= resize(DESCRIPTORS.device.header.rom_offset, descriptor_addr'length);
                                    send_len        <= resize(unsigned(DESCRIPTORS.device.header.bLength), send_len'length);
                                    if unsigned(setup.wLength) < unsigned(DESCRIPTORS.device.header.bLength) then
                                        send_len <= resize(unsigned(setup.wLength), send_len'length);
                                    end if;

                                -- TODO: other descriptors

                                when others => null;
                            end case;

                        -- GET_CONFIGURATION
                        when x"08" =>
                            null; -- TODO

                        when others => null;
                    end case;
                end if;
            end if;

            -- Transmit the response
            -- TODO: handle ACK
            if send_len > 0 and packet_len > 0 then
                EP_OUTPUT.tx_enable <= '1';
                EP_OUTPUT.tx_data   <= descriptor_data;

                if EP_INPUT.tx_read = '1' then
                    descriptor_addr <= descriptor_addr + 1;
                    send_len        <= send_len - 1;
                    packet_len      <= packet_len - 1;
                end if;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                descriptor_addr     <= (others => '0');
                send_len            <= (others => '0');
                EP_OUTPUT.tx_enable <= '0';
                EP_OUTPUT.tx_data   <= (others => '0');
            end if;
        end if;
    end process;

end USB_EndPoint0_arch;
