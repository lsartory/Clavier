-- Clavier | Clavier.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.git_info.all;
use work.keymap.all;
use work.usb_types.all;
use work.usb_descriptors.all;
use work.usb_class_descriptors.all;
use work.utils.all;

--------------------------------------------------

entity Clavier is
    generic (
        USB_VENDOR_ID:  integer range 0 to 65535 := 16#1209#;
        USB_PRODUCT_ID: integer range 0 to 65535 := 16#0008#;
        USB_BCD_DEVICE: integer range 0 to 65535 := 16#0100#;

        LED_BRIGHTNESS: unsigned(15 downto 0) := x"FFFF"
    );
    port (
        CLK_12MHz:    in    std_logic;

        USB_DN:       inout std_logic;
        USB_DP:       inout std_logic;
        USB_DP_PULL:  out   std_logic;

        KEYS:         in    std_logic_vector(105 downto 0);
        LEDS:         out   std_logic_vector(4 downto 0);

        FPGA_RESET:   out   std_logic
    );
end entity Clavier;

--------------------------------------------------

architecture Clavier_arch of Clavier is
    -- USB descriptors
    constant REPORT_DESCRIPTOR: usb_byte_array_t := ( -- TODO: generate this automatically?
        x"05", x"01", -- Usage Page (Generic Desktop)
        x"09", x"06", -- Usage (Keyboard)
        x"A1", x"01", -- Collection (Application)
        x"85", x"01", --   Report ID

        -- Bitmap of keys
        x"95", x"F8", --   Report Count
        x"75", x"01", --   Report Size (1)
        x"15", x"00", --   Logical Minimum (0)
        x"25", x"01", --   Logical Maximum (1)
        x"05", x"07", --   Usage Page (Key Codes)
        x"19", x"04", --   Usage Minimum (KEY_A)
        x"29", x"FB", --   Usage Maximum (KEY_CALC)
        x"81", x"02", --   Input (Data, Variable, Absolute)

        x"C0"         -- End Collection
    );
    constant DESCRIPTORS: usb_descriptors_t := new_usb_descriptors(
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
                            to_byte_array(new_usb_hid_class(
                                0, -- No country code
                                (
                                    0 => from_report_descriptor(REPORT_DESCRIPTOR)
                                )
                            )),
                            (
                                0 => new_usb_endpoint(1, ep_in,  interrupt, no_sync, data, 64, 1),
                                1 => new_usb_endpoint(1, ep_out, interrupt, no_sync, data, 64, 1)
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
            2 => to_usb_string_descriptor("Clavier"),    -- Product
            3 => to_usb_string_descriptor(GIT_DESC)      -- Serial number
        )
    );

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
    signal device_reset:   std_logic;
    signal device_address: usb_dev_addr_t;
    signal ep_input:       usb_ep_input_signals_t;
    signal ep_outputs:     usb_ep_output_signals_array_t(1 downto 0);

    -- Keyboard signals
    signal keys_pd:        std_logic_vector(KEYS'range);
    signal keys_debounced: std_logic_vector(KEYS'range);
    signal report_data:    usb_byte_array_t(0 to 31);

    -- LED signals
    signal led_clrn:   std_logic;
    signal led_states: std_logic_vector(LEDS'range);

    -- Reset signals
    constant RESET_KEY_NUM:      natural := 45;
    constant RESET_DURATION_INT: natural := delay_to_ticks(5 sec, 12 MHz);
    signal reset_counter:        unsigned(unsigned_bit_width(RESET_DURATION_INT) - 1 downto 0);

    -- Input buffer with pull-down resistor
    component IBPD is
        port (I: in std_logic; O: out std_logic);
    end component;
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

    -- Keys preparation
    keys_ibpd_gen: for i in KEYS'range generate
    begin
        -- Input buffer with pull-down resistor
        key_ibpd: IBPD port map (I => KEYS(i), O => keys_pd(i));

        -- Debouncing
        key_deb: entity work.Debouncer
            port map (
                CLK_48MHz     => pll_clk,
                CLRn          => clrn,

                KEY_INPUT     => keys_pd(i),
                KEY_DEBOUNCED => keys_debounced(i)
            );
    end generate;

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

            DEVICE_RESET   => device_reset,
            FRAME_START    => open,

            DEBUG_TX       => open
        );
    USB_DN      <= usb_dn_out when usb_oe = '1' else 'Z';
    USB_DP      <= usb_dp_out when usb_oe = '1' else 'Z';
    USB_DP_PULL <= '1' when usb_dp_pull_enable = '1' else 'Z';

    -- USB endpoint 0
    usb_ep0: entity work.USB_EndPoint0
        generic map (
            DESCRIPTORS => DESCRIPTORS
        )
        port map (
            CLK_48MHz      => pll_clk,
            CLRn           => clrn,

            EP_INPUT       => ep_input,
            EP_OUTPUT      => ep_outputs(0),

            DEVICE_ADDRESS => device_address
        );

    -- USB HID
    report_data <= keys_to_usb_report(keys_debounced, report_data);
    usb_hid: entity work.USB_HID
        generic map (
            REPORT_DESCRIPTOR  => REPORT_DESCRIPTOR,
            MAX_EP0_PACKET_LEN => to_integer(unsigned(DESCRIPTORS.device.bMaxPacketSize0)),
            EP_IN_ID           => to_integer(unsigned(DESCRIPTORS.device.configurations(0).interfaces(0).endpoints(0).bEndpointAddress)),
            EP_OUT_ID          => to_integer(unsigned(DESCRIPTORS.device.configurations(0).interfaces(0).endpoints(1).bEndpointAddress))
        )
        port map (
            CLK_48MHz   => pll_clk,
            CLRn        => clrn,

            EP_INPUT    => ep_input,
            EP_OUTPUT   => ep_outputs(1),

            REPORT_DATA => report_data
        );

    -- LED controller
    led_clrn <= not device_reset;
    led_ctrl: entity work.LedController
        port map (
            CLK_48MHz  => pll_clk,
            CLRn       => led_clrn,

            LED_STATES => led_states,
            BRIGHTNESS => LED_BRIGHTNESS,

            LEDS       => LEDS
        );

    -- Reset process
    process (CLK_12MHz)
    begin
        if rising_edge(CLK_12MHz) then
            -- Detect long presses on the coffee key to reset
            if keys_pd(RESET_KEY_NUM) = '1' then
                if reset_counter < RESET_DURATION_INT then
                    reset_counter <= reset_counter + 1;
                end if;
            else
                reset_counter <= (others => '0');
            end if;
        end if;
    end process;
    FPGA_RESET <= '0' when reset_counter >= RESET_DURATION_INT and keys_pd(RESET_KEY_NUM) = '1' else 'Z';

    -- TODO: use the LEDs to display the key state, for debugging
    process (pll_clk)
    begin
        if rising_edge(pll_clk) then
            for i in keys_debounced'range loop
                if keys_debounced(i) = '1' then
                    led_states <= std_logic_vector(to_unsigned(i + 1, 8)(led_states'range));
                end if;
            end loop;

            if CLRn = '0' then
                led_states <= (others => '0');
            end if;
        end if;
    end process;
end Clavier_arch;
