-- Clavier | USB_PHY.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.usb_types.all;

--------------------------------------------------

entity USB_PHY is
    generic (
        FULL_SPEED: boolean := true
    );
    port (
        CLK_48MHz:   in  std_logic;
        CLRn:        in  std_logic := '1';

        USB_OE:      out std_logic;
        USB_DN_IN:   in  std_logic;
        USB_DP_IN:   in  std_logic;
        USB_DN_OUT:  out std_logic;
        USB_DP_OUT:  out std_logic;

        RX_ACTIVE:   out std_logic;
        RX_DATA:     out usb_byte_t;
        RX_VALID:    out std_logic;
        RX_EOP:      out std_logic;

        RX_ERROR:    out std_logic;
        RX_SUSPEND:  out std_logic;
        RX_RESET:    out std_logic;

        TX_ACTIVE:   out std_logic;
        TX_ENABLE:   in  std_logic;
        TX_DATA:     in  usb_byte_t;
        TX_READ:     out std_logic;

        DEBUG_TX:    out std_logic
    );
end entity USB_PHY;

--------------------------------------------------

architecture USB_PHY_arch of USB_PHY is
    constant LOW_SPEED_BIT_LENGTH:  positive :=      32; -- 1.5 Mbps
    constant FULL_SPEED_BIT_LENGTH: positive :=       4; --  12 Mbps
    constant SUSPEND_LENGTH:        positive := 144_000; -- 3.0 ms
    constant RESET_LENGTH:          positive := 120_000; -- 2.5 ms

    -- Synchronized signals
    signal usb_dn_sync: std_logic;
    signal usb_dp_sync: std_logic;

    -- Receiver clock signals
    signal rx_clock_counter: unsigned(6 downto 0);
    signal rx_clock_pulse:   std_logic;

    -- Line input sampler signals
    type line_sampler_state_t is (idle, sync, data, eop);
    signal line_sampler_state: line_sampler_state_t;
    type line_state_t is (J, K, SE0, SE1);
    signal line_state_sampled: line_state_t;
    signal sync_counter:       unsigned(1 downto 0);
    signal line_state_valid:   std_logic;
    signal reset_counter:      unsigned(17 downto 0);
    signal suspend_counter:    unsigned(17 downto 0);
    signal line_suspend:       std_logic;
    signal line_reset:         std_logic;

    -- Receiver signals
    signal rx_shift_reg:      usb_byte_t;
    signal rx_shift_counter:  unsigned(3 downto 0);
    signal rx_stuffing:       unsigned(3 downto 0);
    signal rx_stuffing_error: std_logic;

    -- Transmitter clock signals
    signal tx_clock_counter: unsigned(6 downto 0);
    signal tx_clock_pulse:   std_logic;

    -- Transmitter signals
    type tx_state_t is (
        idle,
        start_delay_1,
        start_delay_2,
        sending,
        eop_1,
        eop_2,
        eop_3,
        end_delay
    );
    signal tx_state:         tx_state_t;
    signal tx_shift_reg:     usb_byte_t;
    signal tx_shift_counter: unsigned(3 downto 0);
    signal tx_stuffing:      unsigned(3 downto 0);
    signal tx_dn:            std_logic;
    signal tx_dp:            std_logic;
    signal tx_dn_buf:        std_logic;
    signal tx_dp_buf:        std_logic;

    -- Debug UART signals
    signal debug_rx_start:   std_logic;
    signal debug_tx_start:   std_logic;
    signal debug_rx_data:    usb_byte_t;
    signal debug_tx_data:    usb_byte_t;
    signal debug_data:       usb_byte_t;
    signal debug_tx_valid:   std_logic;
    signal debug_rx_valid:   std_logic;
    signal debug_data_valid: std_logic;
    signal debug_rx_eop:     std_logic;
    signal debug_tx_eop:     std_logic;
    signal debug_eop:        std_logic;
begin
    -- Input synchronization
    usb_cdc: entity work.VectorCDC
        port map (
            TARGET_CLK => CLK_48MHz,
            INPUT(0)   => USB_DN_IN,
            INPUT(1)   => USB_DP_IN,
            OUTPUT(0)  => usb_dn_sync,
            OUTPUT(1)  => usb_dp_sync
        );

    -- Receiver clock
    process (CLK_48MHz)
        variable usb_dn_sync_prev: std_logic;
        variable usb_dp_sync_prev: std_logic;
    begin
        if rising_edge(CLK_48MHz) then
            rx_clock_pulse <= '0';

            -- Delay counter
            if rx_clock_counter /= 0 then
                rx_clock_counter <= rx_clock_counter - 1;
            else
                -- Set the reload value for a full bit
                rx_clock_counter <= to_unsigned(LOW_SPEED_BIT_LENGTH, rx_clock_counter'length) - 1;
                if FULL_SPEED then
                    rx_clock_counter <= to_unsigned(FULL_SPEED_BIT_LENGTH, rx_clock_counter'length) - 1;
                end if;
                rx_clock_pulse <= '1';
            end if;

            -- Synchronous reset or resync
            if CLRn = '0' or (FULL_SPEED and usb_dn_sync /= usb_dn_sync_prev) or (not FULL_SPEED and usb_dp_sync /= usb_dp_sync_prev) then
                -- Set the reload value for a half bit
                rx_clock_counter <= to_unsigned(LOW_SPEED_BIT_LENGTH / 2, rx_clock_counter'length) - 2;
                if FULL_SPEED then
                    rx_clock_counter <= to_unsigned(FULL_SPEED_BIT_LENGTH / 2, rx_clock_counter'length) - 2;
                end if;
                rx_clock_pulse <= '0';
            end if;

            usb_dn_sync_prev := usb_dn_sync;
            usb_dp_sync_prev := usb_dp_sync;
        end if;
    end process;

    -- Line input sampling process
    process (CLK_48MHz)
        variable input_vector: std_logic_vector(2 downto 0);
        variable line_state:   line_state_t;
    begin
        if rising_edge(CLK_48MHz) then
            debug_rx_start   <= '0';
            debug_rx_eop     <= '0';
            line_state_valid <= '0';
            line_suspend     <= '0';
            line_reset       <= '0';
            RX_EOP           <= '0';

            -- Decode the line state depending on the chosen speed
            input_vector(2) := '0';
            if FULL_SPEED then
                input_vector(2) := '1';
            end if;
            input_vector(1) := usb_dn_sync;
            input_vector(0) := usb_dp_sync;
            case input_vector is
                when "000"  => line_state := SE0;
                when "001"  => line_state := K;
                when "010"  => line_state := J;
                when "011"  => line_state := SE1;
                when "100"  => line_state := SE0;
                when "101"  => line_state := J;
                when "110"  => line_state := K;
                when others => line_state := SE1;
            end case;

            -- Line sampler state machine
            if rx_clock_pulse = '1' then
                line_state_sampled <= line_state;

                case line_sampler_state is
                    when idle =>
                        -- Wait for the start of a packet
                        sync_counter <= (others => '1');
                        if line_state = K then
                            line_sampler_state <= sync;
                        end if;

                    when sync =>
                        -- Synchronize the clocks
                        if line_state /= line_state_sampled and sync_counter /= 0 then
                            sync_counter <= sync_counter - 1;
                        elsif line_state = K and line_state_sampled = K and sync_counter = 0 then
                            debug_rx_start     <= '1';
                            line_sampler_state <= data;
                        end if;

                    when data =>
                        -- Receive data
                        if line_state = SE0 then
                            line_sampler_state <= eop;
                        else
                            line_state_valid <= '1';
                        end if;

                    when eop =>
                        -- Wait for the end of packet
                        if line_state = J then
                            debug_rx_eop       <= '1';
                            RX_EOP             <= '1';
                            line_sampler_state <= idle;
                        end if;
                end case;
            end if;

            -- Suspend timer
            if line_state /= J then
                suspend_counter <= to_unsigned(SUSPEND_LENGTH, suspend_counter'length);
                line_suspend    <= '0';
            elsif suspend_counter /= 0 then
                suspend_counter <= suspend_counter - 1;
            else
                line_suspend <= '1';
            end if;

            -- Host reset timer
            if line_state /= SE0 then
                reset_counter <= to_unsigned(RESET_LENGTH, reset_counter'length);
                line_reset    <= '0';
            elsif reset_counter /= 0 then
                reset_counter <= reset_counter - 1;
            else
                line_reset <= '1';
            end if;

            -- Synchronous reset
            if CLRn = '0' or tx_state /= idle then
                RX_EOP             <= '0';
                line_suspend       <= '0';
                line_reset         <= '0';
                suspend_counter    <= (others => '1');
                reset_counter      <= (others => '1');
                line_state_valid   <= '0';
                line_sampler_state <= idle;
            end if;
        end if;
    end process;
    RX_ACTIVE  <= '1' when line_sampler_state = data else '0';
    RX_SUSPEND <= line_suspend;
    RX_RESET   <= line_reset;

    -- Receiver process
    process (CLK_48MHz)
        variable prev_line_state: line_state_t;
    begin
        if rising_edge(CLK_48MHz) then
            debug_rx_valid    <= '0';
            rx_stuffing_error <= '0';
            RX_VALID          <= '0';

            -- Receive bits
            if line_state_valid = '1' then
                if line_state_sampled = prev_line_state then
                    if rx_stuffing < 6 then
                        rx_shift_reg     <= '1' & rx_shift_reg(rx_shift_reg'high downto rx_shift_reg'low + 1);
                        rx_shift_counter <= rx_shift_counter + 1;
                        rx_stuffing      <= rx_stuffing + 1;
                    else
                        rx_stuffing_error <= '1';
                    end if;
                else
                    if rx_stuffing < 6 then
                        rx_shift_reg     <= '0' & rx_shift_reg(rx_shift_reg'high downto rx_shift_reg'low + 1);
                        rx_shift_counter <= rx_shift_counter + 1;
                    end if;
                    rx_stuffing <= (others => '0');
                end if;
                prev_line_state := line_state_sampled;
            end if;

            -- Signal full bytes
            if rx_shift_counter = 8 then
                rx_shift_counter <= (others => '0');
                debug_rx_data    <= rx_shift_reg;
                debug_rx_valid   <= '1';
                RX_DATA          <= rx_shift_reg;
                RX_VALID         <= '1';
            end if;

            -- Resynchronization
            if line_sampler_state = idle then
                prev_line_state  := K;
                rx_shift_counter <= (others => '0');
                rx_stuffing      <= (others => '0');
            end if;

            -- Synchronous reset
            if CLRn = '0' or tx_state /= idle then
                RX_DATA           <= (others => '0');
                RX_VALID          <= '0';
                rx_shift_counter  <= (others => '0');
                rx_stuffing       <= (others => '0');
                rx_stuffing_error <= '0';
            end if;
        end if;
    end process;
    RX_ERROR <= rx_stuffing_error;

    -- Transmitter clock
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            tx_clock_pulse <= '0';

            -- Delay counter
            if tx_clock_counter /= 0 then
                tx_clock_counter <= tx_clock_counter - 1;
            else
                -- Set the reload value for a full bit
                tx_clock_counter <= to_unsigned(LOW_SPEED_BIT_LENGTH, tx_clock_counter'length) - 1;
                if FULL_SPEED then
                    tx_clock_counter <= to_unsigned(FULL_SPEED_BIT_LENGTH, tx_clock_counter'length) - 1;
                end if;
                tx_clock_pulse <= '1';
            end if;

            -- Synchronous reset or resync
            if CLRn = '0' then
                tx_clock_counter <= (others => '0');
                tx_clock_pulse   <= '0';
            end if;
        end if;
    end process;

    -- Transmitter process
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            debug_tx_start <= '0';
            debug_tx_valid <= '0';
            debug_tx_eop   <= '0';
            TX_READ        <= '0';

            -- Wait for data to be sent
            if tx_state = idle then
                tx_dn <= '1';
                tx_dp <= '0';
                if FULL_SPEED then
                    tx_dn <= '0';
                    tx_dp <= '1';
                end if;
                tx_shift_counter <= to_unsigned(8, tx_shift_counter'length);
                tx_stuffing      <= (others => '0');
                if TX_ENABLE = '1' then
                    -- Send the sync pattern first
                    debug_tx_start <= '1';
                    tx_shift_reg   <= x"80";
                    tx_state       <= start_delay_1;
                end if;
            end if;

            -- Transmitter state machine
            if tx_clock_pulse = '1' then
                case tx_state is
                    when idle => null;

                    -- Delay a bit before sending
                    when start_delay_1 =>
                        tx_state <= start_delay_2;
                    when start_delay_2 =>
                        tx_state <= sending;

                    -- Send data bit by bit
                    when sending =>
                        tx_shift_reg     <= '0' & tx_shift_reg(tx_shift_reg'high downto tx_shift_reg'low + 1);
                        tx_shift_counter <= tx_shift_counter - 1;

                        -- Check if bit stuffing is required
                        if tx_stuffing = 6 then
                            tx_dn            <= not tx_dn;
                            tx_dp            <= not tx_dp;
                            tx_stuffing      <= (others => '0');
                            tx_shift_reg     <= tx_shift_reg;
                            tx_shift_counter <= tx_shift_counter;
                        elsif tx_shift_reg(tx_shift_reg'low) = '1' then
                            tx_stuffing <= tx_stuffing + 1;
                        else
                            tx_dn       <= not tx_dn;
                            tx_dp       <= not tx_dp;
                            tx_stuffing <= (others => '0');
                        end if;

                        -- Check if more data is available
                        if TX_ENABLE = '1' and tx_shift_counter = 1 and tx_stuffing /= 6 then
                            debug_tx_data    <= TX_DATA;
                            debug_tx_valid   <= '1';
                            tx_shift_reg     <= TX_DATA;
                            tx_shift_counter <= to_unsigned(8, tx_shift_counter'length);
                            TX_READ          <= '1';
                        elsif tx_shift_counter = 0 and (tx_shift_reg(tx_shift_reg'low) = '0' or tx_stuffing /= 6) then
                            tx_dn    <= '0';
                            tx_dp    <= '0';
                            tx_state <= eop_1;
                        end if;

                    -- Send SE0 twice
                    when eop_1 =>
                        tx_state <= eop_2;
                    when eop_2 =>
                        tx_dn <= '1';
                        tx_dp <= '0';
                        if FULL_SPEED then
                            tx_dn <= '0';
                            tx_dp <= '1';
                        end if;
                        tx_state <= eop_3;

                    -- Send J once
                    when eop_3 =>
                        debug_tx_eop <= '1';
                        tx_state     <= end_delay;

                    -- Delay a bit after sending
                    when end_delay =>
                        tx_state <= idle;
                end case;
            end if;

            -- Drive the USB lines
            tx_dn_buf <= tx_dn;
            tx_dp_buf <= tx_dp;
            if tx_state /= idle and tx_state /= start_delay_1 and tx_state /= start_delay_2 and tx_state /= end_delay then
                USB_OE     <= '1';
                USB_DN_OUT <= tx_dn_buf;
                USB_DP_OUT <= tx_dp_buf;
            else
                USB_OE     <= '0';
                USB_DN_OUT <= '0';
                USB_DP_OUT <= '0';
            end if;

            -- Synchronous reset
            if CLRn = '0' then
                USB_OE     <= '0';
                USB_DN_OUT <= '0';
                USB_DP_OUT <= '0';
                TX_READ    <= '0';
                tx_state   <= idle;
            end if;
        end if;
    end process;
    TX_ACTIVE <= '1' when tx_state /= idle else '0';

    -- Debug UART
    debug_data       <= debug_rx_data when debug_rx_valid = '1' else debug_tx_data when debug_tx_valid = '1' else (others => '0');
    debug_data_valid <= debug_rx_valid or debug_tx_valid;
    debug_eop        <= debug_rx_eop   or debug_tx_eop;
    debug: entity work.USB_Debug_UART
        port map (
            CLK_48MHz  => CLK_48MHz,
            CLRn       => CLRn,

            RX_START   => debug_rx_start,
            TX_START   => debug_tx_start,
            DATA       => debug_data,
            DATA_VALID => debug_data_valid,
            EOP        => debug_eop,

            RX_SUSPEND => line_suspend,
            RX_RESET   => line_reset,
            RX_ERROR   => rx_stuffing_error,

            DEBUG_TX   => DEBUG_TX
        );

end USB_PHY_arch;
