-- Clavier | USB_Types.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

package usb_types is
    -- Data types
    subtype usb_byte_t is std_logic_vector( 7 downto 0);
    subtype usb_word_t is std_logic_vector(15 downto 0);

    -- Array types
    type usb_byte_array_t is array(natural range <>) of usb_byte_t;
    type usb_word_array_t is array(natural range <>) of usb_word_t;

    -- Token types
    type usb_token_t is (
        token_none,
        token_out,
        token_in,
        token_setup,
        token_unknown
    );

    -- Address types
    subtype usb_dev_addr_t is unsigned(6 downto 0);
    subtype usb_ep_addr_t  is unsigned(3 downto 0);

    -- Endpoints input/output signals
    type usb_ep_input_signals_t is record
        token:       usb_token_t;
        endpoint:    usb_ep_addr_t;
        start_trans: std_logic;

        rx_reset:             std_logic;
        rx_data_packet:       std_logic;
        rx_data_packet_valid: std_logic;
        rx_data:              usb_byte_t;
        rx_data_valid:        std_logic;
        rx_ack:               std_logic;

        tx_read:              std_logic;
    end record;
    type usb_ep_output_signals_t is record
        tx_ack:    std_logic;
        tx_nak:    std_logic;
        tx_enable: std_logic;
        tx_data:   usb_byte_t;
    end record;
    type usb_ep_output_signals_array_t is array(natural range <>) of usb_ep_output_signals_t;

    -- Setup packet
    type usb_setup_packet_t is record
        bmRequestType: usb_byte_t;
        bRequest:      usb_byte_t;
        wValue:        usb_word_t;
        wIndex:        usb_word_t;
        wLength:       usb_word_t;
    end record;
end package;
