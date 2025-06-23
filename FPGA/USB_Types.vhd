-- Clavier | USB_Types.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

package usb_types is
    subtype usb_byte_t is std_logic_vector( 7 downto 0);
    subtype usb_word_t is std_logic_vector(15 downto 0);

    type usb_byte_array_t is array(natural range <>) of usb_byte_t;
    type usb_word_array_t is array(natural range <>) of usb_word_t;

    type usb_token_t is (
        token_none,
        token_out,
        token_in,
        token_setup,
        token_unknown
    );

    subtype usb_dev_addr_t is unsigned(6 downto 0);
    subtype usb_endpoint_t is unsigned(3 downto 0);
end package;
