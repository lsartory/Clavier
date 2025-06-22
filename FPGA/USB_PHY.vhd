-- Clavier | USB_PHY.vhd
-- Copyright (c) 2025 L. Sartory
-- SPDX-License-Identifier: MIT

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
        RX_DATA:     out std_logic_vector(7 downto 0);
        RX_VALID:    out std_logic;
        RX_EOP:      out std_logic;

        RX_ERROR:    out std_logic;
        RX_SUSPEND:  out std_logic;
        RX_RESET:    out std_logic;

        TX_ACTIVE:   out std_logic;
        TX_ENABLE:   in  std_logic;
        TX_DATA:     in  std_logic_vector(7 downto 0);
        TX_READ:     out std_logic
    );
end entity USB_PHY;

--------------------------------------------------

architecture USB_PHY_arch of USB_PHY is
    constant LOW_SPEED_BIT_LENGTH:  natural :=      32; -- 1.5 Mbps
    constant FULL_SPEED_BIT_LENGTH: natural :=       4; --  12 Mbps
    constant SUSPEND_LENGTH:        natural := 144_000; -- 3.0 ms
    constant RESET_LENGTH:          natural := 120_000; -- 2.5 ms

    signal usb_dn_sync: std_logic;
    signal usb_dp_sync: std_logic;

    type line_state_t is (J, K, SE0, SE1);
    signal line_state:         line_state_t;
    signal line_state_sampled: line_state_t;
    signal line_idle:          std_logic;
    signal line_idle_prev:     std_logic;
    signal line_state_valid:   std_logic;
    signal line_counter:       unsigned(6 downto 0);
    signal line_timeout:       unsigned(3 downto 0);

    signal rx_idle:          std_logic;
    signal rx_idle_prev:     std_logic;
    signal rx_shift_reg:     std_logic_vector(7 downto 0);
    signal rx_shift_counter: unsigned(3 downto 0);
    signal rx_stuffing:      unsigned(3 downto 0);

    type eop_shift_reg_t is array(natural range <>) of line_state_t;
    signal eop_shift_reg: eop_shift_reg_t(2 downto 0);

    signal reset_counter:   unsigned(17 downto 0);
    signal suspend_counter: unsigned(17 downto 0);

    type tx_state_t is (idle, start_delay, sending, eop_1, eop_2, end_delay);
    signal tx_state:         tx_state_t;
    signal tx_divider:       unsigned(7 downto 0);
    signal tx_shift_reg:     std_logic_vector(7 downto 0);
    signal tx_shift_counter: unsigned(3 downto 0);
    signal tx_stuffing:      unsigned(3 downto 0);
    signal tx_dn:            std_logic;
    signal tx_dp:            std_logic;
    signal tx_dn_buf:        std_logic;
    signal tx_dp_buf:        std_logic;
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

    -- Line input sampling process
    process (CLK_48MHz)
        variable input_vector:     std_logic_vector(2 downto 0);
        variable usb_dn_sync_prev: std_logic;
        variable usb_dp_sync_prev: std_logic;
    begin
        if rising_edge(CLK_48MHz) then
            line_state_valid <= '0';

            -- Decode the line state depending on the chosen speed
            input_vector(2) := '0';
            if FULL_SPEED then
                input_vector(2) := '1';
            end if;
            input_vector(1) := usb_dn_sync;
            input_vector(0) := usb_dp_sync;
            case input_vector is
                when "000"  => line_state <= SE0;
                when "001"  => line_state <= K;
                when "010"  => line_state <= J;
                when "011"  => line_state <= SE1;
                when "100"  => line_state <= SE0;
                when "101"  => line_state <= J;
                when "110"  => line_state <= K;
                when others => line_state <= SE1;
            end case;

            -- Detect edges or sample bits
            if (FULL_SPEED and usb_dn_sync /= usb_dn_sync_prev) or (not FULL_SPEED and usb_dp_sync /= usb_dp_sync_prev) then
                -- Set the next sampling time for a half bit, according to the selected speed
                line_counter <= to_unsigned(LOW_SPEED_BIT_LENGTH / 2, line_counter'length) - 1;
                if FULL_SPEED then
                    line_counter <= to_unsigned(FULL_SPEED_BIT_LENGTH / 2, line_counter'length) - 1;
                end if;
                line_timeout <= (others => '0');
                line_idle    <= '0';
            elsif line_counter = 0 and line_idle = '0' then
                -- Set the next sampling time for a full bit, according to the selected speed
                line_counter <= to_unsigned(LOW_SPEED_BIT_LENGTH, line_counter'length) - 1;
                if FULL_SPEED then
                    line_counter <= to_unsigned(FULL_SPEED_BIT_LENGTH, line_counter'length) - 1;
                end if;
                line_timeout <= line_timeout + 1;

                -- Sample the line state
                line_state_sampled <= line_state;
                line_state_valid   <= '1';
            elsif line_counter > 0 then
                line_counter <= line_counter - 1;
            end if;

            -- Resynchronization
            if (rx_idle = '1' and rx_idle_prev = '0') or line_timeout >= 8 then
                line_idle <= '1';
            end if;

            -- Synchronous reset
            if CLRn = '0' or tx_state /= idle then
                line_idle          <= '1';
                line_counter       <= (others => '0');
                line_timeout       <= (others => '0');
                line_state         <= SE0;
                line_state_sampled <= SE0;
                line_state_valid   <= '0';
            end if;

            line_idle_prev   <= line_idle;
            usb_dn_sync_prev := usb_dn_sync;
            usb_dp_sync_prev := usb_dp_sync;
        end if;
    end process;

    -- Receiver process
    process (CLK_48MHz)
        variable prev_line_state: line_state_t;
    begin
        if rising_edge(CLK_48MHz) then
            RX_VALID <= '0';
            RX_EOP   <= '0';
            RX_ERROR <= '0';

            -- Line activity detection
            if line_state_valid = '1' and line_state_sampled = K then
                rx_idle <= '0';
            end if;

            -- Receive bits
            if line_state_valid = '1' then
                if line_state_sampled = prev_line_state then
                    if rx_stuffing < 6 then
                        rx_shift_reg     <= '1' & rx_shift_reg(rx_shift_reg'high downto rx_shift_reg'low + 1);
                        rx_shift_counter <= rx_shift_counter + 1;
                        rx_stuffing      <= rx_stuffing + 1;
                    else
                        rx_idle  <= '1';
                        RX_ERROR <= '1';
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
                RX_DATA          <= rx_shift_reg;
                RX_VALID         <= '1';
            end if;

            -- End of packet shift register
            if line_state_valid = '1' then
                eop_shift_reg <= eop_shift_reg(eop_shift_reg'high - 1 downto eop_shift_reg'low) & line_state_sampled;
            end if;
            if eop_shift_reg = (SE0, SE0, J) then
                eop_shift_reg <= (others => SE0);
                rx_idle       <= '1';
                RX_EOP        <= '1';
            end if;

            -- Suspend timer
            if line_state /= J then
                suspend_counter <= (others => '0');
                RX_SUSPEND      <= '0';
            elsif suspend_counter <= SUSPEND_LENGTH then
                suspend_counter <= suspend_counter + 1;
            else
                RX_SUSPEND <= '1';
            end if;

            -- Host reset timer
            if line_state /= SE0 then
                reset_counter <= (others => '0');
                RX_RESET      <= '0';
            elsif reset_counter <= RESET_LENGTH then
                reset_counter <= reset_counter + 1;
            else
                RX_RESET <= '1';
            end if;

            -- Resynchronization
            if line_idle = '0' and line_idle_prev = '1' then
                rx_shift_reg     <= (others => '0');
                rx_shift_counter <= (others => '0');
                rx_stuffing      <= (others => '0');
            end if;

            -- Synchronous reset
            if CLRn = '0' or tx_state /= idle then
                rx_idle          <= '1';
                rx_shift_reg     <= (others => '0');
                rx_shift_counter <= (others => '0');
                rx_stuffing      <= (others => '0');

                RX_DATA          <= (others => '0');
                RX_VALID         <= '0';
                RX_EOP           <= '0';

                RX_ERROR         <= '0';
                RX_SUSPEND       <= '0';
                RX_RESET         <= '0';
            end if;

            rx_idle_prev <= rx_idle;
        end if;
    end process;
    RX_ACTIVE <= not rx_idle;

    -- Transmitter process
    process (CLK_48MHz)
    begin
        if rising_edge(CLK_48MHz) then
            TX_READ <= '0';

            -- Wait for data to be sent
            if tx_state = idle then
                tx_divider <= to_unsigned(LOW_SPEED_BIT_LENGTH * 2, tx_divider'length) - 1;
                tx_dn      <= '1';
                tx_dp      <= '0';
                if FULL_SPEED then
                    tx_divider <= to_unsigned(FULL_SPEED_BIT_LENGTH * 2, tx_divider'length) - 1;
                    tx_dn      <= '0';
                    tx_dp      <= '1';
                end if;
                tx_shift_counter <= to_unsigned(8, tx_shift_counter'length);
                tx_stuffing      <= (others => '0');
                if TX_ENABLE = '1' then
                    tx_shift_reg <= TX_DATA;
                    TX_READ      <= '1';
                    tx_state     <= start_delay;
                end if;
            elsif tx_divider > 0 then
                -- Divide the clock frequency to reach the target bitrate
                tx_divider <= tx_divider - 1;
            else
                case tx_state is
                    when idle => null;

                    when start_delay =>
                        -- Delay a bit before sending
                        tx_state <= sending;

                    when sending =>
                        -- Send data bit by bit
                        tx_shift_reg     <= '0' & tx_shift_reg(tx_shift_reg'high downto tx_shift_reg'low + 1);
                        tx_shift_counter <= tx_shift_counter - 1;
                        tx_stuffing      <= (others => '0');
                        tx_divider       <= to_unsigned(LOW_SPEED_BIT_LENGTH, tx_divider'length) - 1;
                        if FULL_SPEED then
                            tx_divider <= to_unsigned(FULL_SPEED_BIT_LENGTH, tx_divider'length) - 1;
                        end if;

                        -- Check if bit stuffing is required
                        if tx_shift_reg(tx_shift_reg'low) = '1' then
                            tx_stuffing <= tx_stuffing + 1;
                            if tx_stuffing = 6 then
                                tx_dn            <= not tx_dn;
                                tx_dp            <= not tx_dp;
                                tx_stuffing      <= (others => '0');
                                tx_shift_reg     <= tx_shift_reg;
                                tx_shift_counter <= tx_shift_counter;
                            end if;
                        else
                            tx_dn <= not tx_dn;
                            tx_dp <= not tx_dp;
                        end if;

                        -- Check if more data is available
                        if TX_ENABLE = '1' and tx_shift_counter = 1 and (tx_shift_reg(tx_shift_reg'low) = '0' or tx_stuffing /= 6) then
                            tx_shift_reg     <= TX_DATA;
                            tx_shift_counter <= to_unsigned(8, tx_shift_counter'length);
                            TX_READ          <= '1';
                        elsif tx_shift_counter = 0 and (tx_shift_reg(tx_shift_reg'low) = '0' or tx_stuffing /= 6) then
                            tx_dn      <= '0';
                            tx_dp      <= '0';
                            tx_divider <= to_unsigned(LOW_SPEED_BIT_LENGTH * 2, tx_divider'length) - 1;
                            if FULL_SPEED then
                                tx_divider <= to_unsigned(FULL_SPEED_BIT_LENGTH * 2, tx_divider'length) - 1;
                            end if;
                            tx_state <= eop_1;
                        end if;

                    when eop_1 =>
                        -- Send SE0 twice
                        tx_divider <= to_unsigned(LOW_SPEED_BIT_LENGTH, tx_divider'length) - 1;
                        tx_dn      <= '1';
                        tx_dp      <= '0';
                        if FULL_SPEED then
                            tx_divider <= to_unsigned(FULL_SPEED_BIT_LENGTH, tx_divider'length) - 1;
                            tx_dn      <= '0';
                            tx_dp      <= '1';
                        end if;
                        tx_state <= eop_2;

                    when eop_2 =>
                        -- Send J once
                        tx_divider <= to_unsigned(LOW_SPEED_BIT_LENGTH, tx_divider'length) - 1;
                        if FULL_SPEED then
                            tx_divider <= to_unsigned(FULL_SPEED_BIT_LENGTH, tx_divider'length) - 1;
                        end if;
                        tx_state <= end_delay;

                    when end_delay =>
                        -- Delay a bit after sending
                        tx_state <= idle;
                end case;
            end if;

            -- Drive the USB lines
            tx_dn_buf <= tx_dn;
            tx_dp_buf <= tx_dp;
            if tx_state /= idle and tx_state /= start_delay and tx_state /= end_delay then
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
    TX_ACTIVE <= '0' when tx_state = idle else '1';

end USB_PHY_arch;
