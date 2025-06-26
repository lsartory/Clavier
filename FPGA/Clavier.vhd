-- Clavier | Clavier.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.usb_types.all;
use work.usb_descriptors.all;

--------------------------------------------------

entity Clavier is
    generic (
        USB_VENDOR_ID:  integer range 0 to 65535 := 16#1209#;
        USB_PRODUCT_ID: integer range 0 to 65535 := 16#0008#;
        USB_BCD_DEVICE: integer range 0 to 65535 := 16#0100#
    );
    port (
        CLK_12MHz:    in    std_logic;

        USB_DN:       inout std_logic;
        USB_DP:       inout std_logic;
        USB_DP_PULL:  out   std_logic;

        USB_DEBUG_TX: out   std_logic
    );
end entity Clavier;

--------------------------------------------------

architecture Clavier_arch of Clavier is
    -- Common signals
    signal clrn:       std_logic;
    signal pll_clk:    std_logic;
    signal pll_locked: std_logic;

    -- USB signals
    signal usb_oe:             std_logic;
    signal usb_dn_out:         std_logic;
    signal usb_dp_out:         std_logic;
    signal usb_dp_pull_enable: std_logic;

    -- USB device signals
    signal device_address: usb_dev_addr_t;
    signal ep_input:       usb_ep_input_signals_t;
    signal ep_outputs:     usb_ep_output_signals_array_t(0 downto 0);
begin

    -- PLL for the USB controller
    pll: entity work.PLL
        port map
        (
            INPUT_CLK  => CLK_12MHz,
            OUTPUT_CLK => pll_clk,
            PLL_LOCKED => pll_locked
        );
    pll_cdc: entity work.VectorCDC
        port map (
            TARGET_CLK => pll_clk,
            INPUT(0)   => pll_locked,
            OUTPUT(0)  => clrn
        );

    -- USB device
    usb_dev: entity work.USB_Device
        port map (
            CLK_48MHz      => pll_clk,
            CLRn           => clrn,

            USB_OE         => usb_oe,
            USB_DN_IN      => USB_DN,
            USB_DP_IN      => USB_DP,
            USB_DN_OUT     => usb_dn_out,
            USB_DP_OUT     => usb_dp_out,
            USB_DN_PULL    => open,
            USB_DP_PULL    => usb_dp_pull_enable,

            DEVICE_ADDRESS => device_address,

            EP_INPUT       => ep_input,
            EP_OUTPUTS     => ep_outputs,

            FRAME_START    => open,

            DEBUG_TX       => USB_DEBUG_TX
        );
    USB_DN      <= usb_dn_out when usb_oe = '1' else 'Z';
    USB_DP      <= usb_dp_out when usb_oe = '1' else 'Z';
    USB_DP_PULL <= '1' when usb_dp_pull_enable = '1' else 'Z';

    -- USB Endpoint 0
    usb_ep0: entity work.USB_EndPoint0
        generic map (
            DESCRIPTORS => new_usb_descriptors(
                -- USB device
                new_usb_device(
                    16#00#, -- No device class
                    16#00#, -- No device sub-class
                    16#00#, -- No device protocol
                    64,     -- Max packet size
                    USB_VENDOR_ID,
                    USB_PRODUCT_ID,
                    USB_BCD_DEVICE,
                    1, -- Manufacturer string index
                    2, -- Product string index
                    3, -- Serial number string index
                    (
                        0 => new_usb_configuration(
                            0,     -- No description string
                            false, -- Bus-powered
                            false, -- No remote wakeup
                            100,   -- mA max. power
                            (
                                0 => new_usb_interface(
                                    0,      -- Interface #0
                                    0,      -- No alternate setting
                                    16#03#, -- HID class
                                    16#00#, -- Non-boot sub-class
                                    16#00#, -- Non-boot protocol
                                    0,      -- No description string
                                    (
                                        0 => new_usb_endpoint(1, ep_in,  interrupt, no_sync, data, 8, 1), -- TODO: max packet size?
                                        1 => new_usb_endpoint(1, ep_out, interrupt, no_sync, data, 8, 1)  -- TODO: max packet size?
                                    )
                                )
                            )
                        )
                    )
                ),

                -- Strings
                (
                    0 => new_usb_string_zero((0 => x"0409")),    -- English (United States)
                    1 => to_usb_string_descriptor("L. Sartory"), -- Manufacturer
                    2 => to_usb_string_descriptor("USB test"),   -- Product
                    3 => to_usb_string_descriptor("000001")      -- Serial number
                )
            )
        )
        port map (
            CLK_48MHz      => pll_clk,
            CLRn           => clrn,

            EP_INPUT       => ep_input,
            EP_OUTPUT      => ep_outputs(0),

            DEVICE_ADDRESS => device_address
        );

end Clavier_arch;
