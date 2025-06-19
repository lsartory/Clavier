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
        RX_RESET:    out std_logic
    );
end entity USB_PHY;

--------------------------------------------------

architecture USB_PHY_arch of USB_PHY is
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

    signal reset_counter:   unsigned(18 downto 0);
    signal suspend_counter: unsigned(18 downto 0);
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
                line_counter <= to_unsigned(16, line_counter'length) - 1;
                if FULL_SPEED then
                    line_counter <= to_unsigned(2, line_counter'length) - 1;
                end if;
                line_timeout <= (others => '0');
                line_idle    <= '0';
            elsif line_counter = 0 and line_idle = '0' then
                -- Set the next sampling time for a full bit, according to the selected speed
                line_counter <= to_unsigned(32, line_counter'length) - 1;
                if FULL_SPEED then
                    line_counter <= to_unsigned(4, line_counter'length) - 1;
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
            if CLRn = '0' then
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
            RX_VALID   <= '0';
            RX_EOP     <= '0';
            RX_ERROR   <= '0';

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
                rx_idle <= '1';
                RX_EOP  <= '1';
            end if;

            -- Suspend timer
            if line_state /= J then
                suspend_counter <= (others => '0');
                RX_SUSPEND      <= '0';
            elsif suspend_counter < 288_000 then -- 3 ms
                suspend_counter <= suspend_counter + 1;
            else
                RX_SUSPEND <= '1';
            end if;

            -- Host reset timer
            if line_state /= SE0 then
                reset_counter <= (others => '0');
                RX_RESET      <= '0';
            elsif reset_counter < 240_000 then -- 2.5 ms
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
            if CLRn = '0' then
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

end USB_PHY_arch;
