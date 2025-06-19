-- Clavier | USB_Device.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity USB_Device is
    generic (
        FULL_SPEED: boolean := true
    );
    port (
        CLK_96MHz:   in  std_logic;
        CLRn:        in  std_logic := '1';

        USB_OE:      out std_logic;
        USB_DN_IN:   in  std_logic;
        USB_DP_IN:   in  std_logic;
        USB_DN_OUT:  out std_logic;
        USB_DP_OUT:  out std_logic;
        USB_DN_PULL: out std_logic;
        USB_DP_PULL: out std_logic
    );
end entity USB_Device;

--------------------------------------------------

architecture USB_Device_arch of USB_Device is
    signal rx_active:  std_logic;
    signal rx_data:    std_logic_vector(7 downto 0);
    signal rx_valid:   std_logic;
    signal rx_eop:     std_logic;
    signal rx_error:   std_logic;
    signal rx_suspend: std_logic;
    signal rx_reset:   std_logic;

    type usb_state_t is (
        detached,
        connect,
        idle,
        sync,
        pid,
        data,
        eop,
        suspend,
        reset
    );
    signal usb_state: usb_state_t;
    signal rx_pid: std_logic_vector(3 downto 0);
begin
    usb_phy: entity work.USB_PHY
        generic map (
            FULL_SPEED => FULL_SPEED
        )
        port map (
            CLK_96MHz   => clk_96MHz,
            CLRn        => clrn,

            USB_OE      => USB_OE,
            USB_DN_IN   => USB_DN_IN,
            USB_DP_IN   => USB_DP_IN,
            USB_DN_OUT  => USB_DN_OUT,
            USB_DP_OUT  => USB_DP_OUT,

            RX_ACTIVE   => rx_active,
            RX_DATA     => rx_data,
            RX_VALID    => rx_valid,
            RX_EOP      => rx_eop,

            RX_ERROR    => rx_error,
            RX_SUSPEND  => rx_suspend,
            RX_RESET    => rx_reset
        );

    -- State handling process
    process (CLK_96MHz)
    begin
        if rising_edge(CLK_96MHz) then
            case usb_state is
                when detached =>
                    -- Keep all lines deactivated
                    USB_OE      <= '0';
                    USB_DN_OUT  <= '0';
                    USB_DP_OUT  <= '0';
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
                    -- Detect sync patterns
                    if rx_active = '1' then
                        usb_state <= sync;
                    end if;

                when sync =>
                    -- Wait until synchronization is complete
                    if rx_valid = '1' then
                        usb_state <= idle;
                        if rx_data = x"80" then
                            usb_state <= pid;
                        end if;
                    end if;

                when pid =>
                    -- Get the packet identifier
                    if rx_valid = '1' then
                        usb_state <= data;
                        rx_pid    <= rx_data(3 downto 0);
                        for i in 0 to 3 loop
                            if rx_data(i) = rx_data(i + 4) then
                                usb_state <= idle;
                            end if;
                        end loop;
                    end if;

                when data =>
                    -- Detect end of packet
                    if rx_eop = '1' then
                        usb_state <= eop;
                    end if;

                when eop =>
                    usb_state <= idle;

                when suspend => null;
                    -- Low power mode
                    if rx_suspend = '0' then
                        usb_state <= idle;
                    end if;

                when reset =>
                    -- Host reset
                    if rx_reset = '0' then
                        usb_state <= detached;
                    end if;
            end case;

            -- Handle special receiver events
            if rx_reset = '1' then
                usb_state <= reset;
            elsif rx_error = '1' then
                usb_state <= idle;
            elsif rx_suspend = '1' then
                usb_state <= suspend;
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                usb_state <= detached;
            end if;
        end if;
    end process;
end USB_Device_arch;
