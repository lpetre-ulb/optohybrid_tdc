----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    calibration - behavioral
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This module builds a Look-Up Table for calibrating the delay line and then uses
-- it to convert the progression in the delay line to timestamp in ps. Its block 
-- diagram is present in the documentation.
-- As summary, once a calibration is requested by the 'calibrate_i' signal, the 
-- entity asks for calibration events though the 'need_calib_data_o' signal. It 
-- builds an histogram of 25.000 events that is integrated and divided by 8 
-- (25.000/3.125) to build the LUT. This LUT is then used to convert 
-- 'fine_counter_i' in timestamp in ps.
-- The LUT is accessible by the 'callut_addr_i' and 'callut_data_o' signals for 
-- debugging purposes.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity calibration is
port(
    -- Clock
    clk_i             : in std_logic;
    reset_i           : in std_logic;

    -- Inputs
    fine_counter_i    : in std_logic_vector(8 downto 0);
    valid_i           : in std_logic;

    -- Outputs
    fine_time_o       : out std_logic_vector(11 downto 0);
    valid_o           : out std_logic;

    -- Controls
    calibrate_i       : in std_logic;
    need_calib_data_o : out std_logic;
    done_o            : out std_logic;

    -- Calibration LUT access
    callut_addr_i : in std_logic_vector(8 downto 0);
    callut_data_o : out std_logic_vector(11 downto 0) );
end calibration;

architecture behavioral of calibration is

    -- Counter for addresses
    signal addr_cnt     : std_logic_vector(8 downto 0) := (others => '0');
    signal addr_cnt_rst : std_logic := '1';

    -- Accumulator
    signal acc     : std_logic_vector(14 downto 0) := (others => '0');
    signal acc_rst : std_logic := '1';

    -- Delayed signals
    signal addr_cnt_d1     : std_logic_vector(8 downto 0) := (others => '0');
    signal fine_counter_d1 : std_logic_vector(8 downto 0) := (others => '0');
    signal valid_d1        : std_logic := '0';

    -- FSM
    type state_t is (IDLE, 
                     CLEAR, 
                     ACQUIRE, UPDATE_HIST, 
                     UPDATE_LUT, FLUSH );
    signal state : state_t := IDLE;
    
    signal evt_cnt : integer range 0 to 25000 := 0;

    -- Controls
    signal clear_hist_we, inc_hist_we, lut_we : std_logic_vector(0 downto 0) := "0";

    -- Signals between BRAMs
    signal hist_inc_out, hist_inc_in : std_logic_vector(14 downto 0) := (others => '0');
    signal hist_out : std_logic_vector(14 downto 0) := (others => '0');
    signal lut_in : std_logic_vector(14 downto 0) := (others => '0');

    -- Slection of addresses for each port
    signal addr_sel : std_logic := '0';
    signal hist_addra, hist_addrb, lut_addra : std_logic_vector(8 downto 0) := (others => '0');

begin

    addr_cnt_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if addr_cnt_rst = '1' or reset_i = '1' then
                addr_cnt <= (others => '0');
            else
                addr_cnt <= std_logic_vector(unsigned(addr_cnt) + 1);
            end if;
        end if;
    end process;
    
    lut_in <= std_logic_vector(unsigned(acc) + unsigned(hist_out));
    
    acc_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if acc_rst = '1' or reset_i = '1' then
                acc <= (others => '0');
            else
                acc <= lut_in;
            end if;
        end if;
    end process;
    
    delays_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                addr_cnt_d1     <= (others => '0');
                fine_counter_d1 <= (others => '0');
                valid_d1        <= '0';
            else
                addr_cnt_d1     <= addr_cnt;
                fine_counter_d1 <= fine_counter_i;
                valid_d1        <= valid_i;
            end if;
        end if;
    end process;

    FSM_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                state <= IDLE;
                evt_cnt <= 0;

                addr_cnt_rst <= '1';
                addr_sel <= '0';
                
                acc_rst <= '1';

                clear_hist_we <= "0";
                inc_hist_we <= "0";
                lut_we <= "0";
                
                need_calib_data_o <= '0';
                valid_o <= '0';
                done_o <= '0';
            else
                state <= state;
                evt_cnt <= evt_cnt;

                addr_cnt_rst <= '1';
                addr_sel <= '0';
                
                acc_rst <= '1';

                clear_hist_we <= "0";
                inc_hist_we <= "0";
                lut_we <= "0";
                
                need_calib_data_o <= '1';
                valid_o <= '0';
                done_o <= '0';

                case state is
                    when IDLE =>
                        done_o <= '1';
                        valid_o <= valid_d1;
                        need_calib_data_o <= '0';
                              
                        if (calibrate_i = '1') then
                            state <= CLEAR;
                            addr_cnt_rst <= '0';
                            addr_sel <= '1';
                            clear_hist_we <= "1";
                        end if;

                    when CLEAR =>
                        addr_cnt_rst <= '0';
                        addr_sel <= '1';
                        clear_hist_we <= "1";

                        if addr_cnt = "111111111" then
                            state <= ACQUIRE;
                            addr_sel <= '0';
                            clear_hist_we <= "0";
                            evt_cnt <= 0;
                        end if;

                    when ACQUIRE =>
                        if valid_i = '1' then
                            state <= UPDATE_HIST;
                            inc_hist_we <= "1";
                            evt_cnt <= evt_cnt + 1;
                        end if;
                        
                    when UPDATE_HIST =>                    
                        if evt_cnt < 25000 then
                            state <= ACQUIRE;
                        else
                            state <= UPDATE_LUT;
                            addr_cnt_rst <= '0';
                            addr_sel <= '1';
                        end if;

                    when UPDATE_LUT =>
                        need_calib_data_o <= '0';
                        addr_cnt_rst <= '0';
                        addr_sel <= '1';
                        acc_rst <= '0';
                        lut_we <= "1";

                        if addr_cnt_d1 = "111111111" then
                            state <= FLUSH;
                            lut_we <= "0";
                            addr_sel <= '0';
                        end if;
                        
                    when FLUSH =>
                        need_calib_data_o <= '0';
                        state <= IDLE;

                    when others =>
                        state <= IDLE;
                    end case;
                end if; -- reset_i
        end if; -- rising_edge(
    end process;
    
    -- Histogram BRAM
    hist_addra <= addr_cnt when addr_sel = '1' else fine_counter_i;
    hist_addrb <= addr_cnt when addr_sel = '1' else fine_counter_d1;

    hist_inc_in <= std_logic_vector(unsigned(hist_inc_out) + 1);

    hist_inst : entity work.ram512x15
    port map (
        clka => clk_i,
        wea => clear_hist_we,
        addra => hist_addra,
        dina => "000000000000000",
        douta => hist_inc_out,

        clkb => clk_i,
        web => inc_hist_we,
        addrb => hist_addrb,
        dinb => hist_inc_in,
        doutb => hist_out );

    -- LUT BRAM
    lut_addra <= addr_cnt_d1 when addr_sel = '1' else fine_counter_i;

    lut_inst : entity work.ram512x12
    port map (
        clka => clk_i,
        wea => lut_we,
        addra => lut_addra,
        -- We shift by 3 (divide by 8) because we have 
        -- 25000 events with a period of 3125ns.
        dina => lut_in(14 downto 3),
        douta => fine_time_o,

        clkb  => clk_i,
        addrb => callut_addr_i,
        doutb => callut_data_o,
        web   => "0",
        dinb  => "000000000000" );

end behavioral;

-- vim: set expandtab tabstop=4 shiftwidth=4:

