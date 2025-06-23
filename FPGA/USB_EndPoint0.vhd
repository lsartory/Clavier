-- Clavier | USB_EndPoint0.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.usb_types.all;
use work.usb_descriptors.all;

--------------------------------------------------
entity USB_EndPoint0 is
    port (
        CLK_48MHz:            in  std_logic;
        CLRn:                 in  std_logic := '1';

        TOKEN:                in  usb_token_t;
        ENDPOINT:             in  usb_endpoint_t;

        RX_DATA_PACKET:       in  std_logic;
        RX_DATA_PACKET_VALID: in  std_logic;
        RX_DATA:              in  usb_byte_t;
        RX_DATA_VALID:        in  std_logic;
        RX_EOP:               in  std_logic;

        DEVICE_ADDRESS:       out usb_dev_addr_t
    );
end entity USB_EndPoint0;

--------------------------------------------------

architecture USB_EndPoint0_arch of USB_EndPoint0 is
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
    -- TODO
begin

    -- Setup packet handler
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            -- Deserialize the setup packet
            if RX_DATA_PACKET = '1' and TOKEN = token_setup and ENDPOINT = 0 then
                if RX_DATA_VALID = '1' then
                    setup_byte_counter <= setup_byte_counter + 1;

                    case to_integer(setup_byte_counter) is
                        when 0 => setup.valid <= '0';
                                  setup.bmRequestType        <= RX_DATA;
                        when 1 => setup.bRequest             <= RX_DATA;
                        when 2 => setup.wValue( 7 downto 0)  <= RX_DATA;
                        when 3 => setup.wValue(15 downto 8)  <= RX_DATA;
                        when 4 => setup.wIndex( 7 downto 0)  <= RX_DATA;
                        when 5 => setup.wIndex(15 downto 8)  <= RX_DATA;
                        when 6 => setup.wLength( 7 downto 0) <= RX_DATA;
                        when 7 => setup.wLength(15 downto 8) <= RX_DATA;
                        when others =>
                            -- Ignore extra bytes
                            setup_byte_counter <= setup_byte_counter;
                    end case;
                end if;
            elsif RX_DATA_PACKET_VALID = '1' and TOKEN = token_setup and ENDPOINT = 0 then
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
            if setup.valid = '1' and RX_EOP = '1' and TOKEN = token_in and ENDPOINT = 0 then
                -- Check what kind of answer is expected
                if setup.bmRequestType = x"80" then
                    case setup.bRequest is
                        when x"00" => -- GET_STATUS
                            null; -- TODO
                        when x"06" => -- GET_DESCRIPTOR
                            null; -- TODO
                        when x"08" => -- GET_CONFIGURATION
                            null; -- TODO
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process;

end USB_EndPoint0_arch;
