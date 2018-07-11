----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    tdc_cdc - behavioral
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This entity is a clock domain crosser designed to transmit the TDC outputs from
-- 'clk_8x_i' to 'clk_1x_i'.
-- The events of interest are signaled by the 'valid_i' flag which lasts 1 
-- 'clk_8x_i' clock cycle. Once such an event is received, internally we sample
-- and store the signals for 8 clock cycles to be sure that 'clk_1x_i' will see and
-- sample it.
-- Along the transmitted signals ('valid_i' and 'fine_counter_i'), we add a coarse
-- counter, 'coarse_counter_o', to know when the inital signals arrived within the 
-- 'clk_1x_i' period.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity tdc_cdc is
    port (
        -- Clocks
        clk_1x_i : in std_logic;
        clk_8x_i : in std_logic;
        reset_i  : in std_logic;

        -- Inputs
        fine_counter_i : in std_logic_vector(8 downto 0);
        valid_i        : in std_logic;

        -- Outputs
        coarse_counter_o : out std_logic_vector(2 downto 0);
        fine_counter_o   : out std_logic_vector(8 downto 0);
        valid_o          : out std_logic );
end tdc_cdc;

architecture behavioral of tdc_cdc is

    signal coarse_counter_i : std_logic_vector(2 downto 0) := "000";

    signal mono_state : std_logic := '0';
    signal mono_cnt   : integer range 0 to 7 := 0;
    signal mono_ce    : std_logic := '1';

    signal coarse_counter : std_logic_vector(2 downto 0) := "000";
    signal fine_counter   : std_logic_vector(8 downto 0) := "000000000";
    signal valid          : std_logic := '0';

begin

    coarse_counter_inst : entity work.coarse_counter
    port map (
        clk_1x_i  => clk_1x_i,
        clk_8x_i  => clk_8x_i,
        reset_i   => reset_i,
        counter_o => coarse_counter_i
    );

    monostable_p : process(clk_8x_i)
    begin
        if rising_edge(clk_8x_i) then
            if reset_i = '1' then
                mono_state <= '0';
                mono_cnt <= 0;
                mono_ce <= '1';
            else
                if mono_state = '0' then
                    mono_state <= '0';
                    mono_cnt <= 0;
                    mono_ce <= '1';

                    if valid_i = '1' then
                        mono_state <= '1';
                        mono_ce <= '0';
                    end if;
                else
                    mono_state <= '1';
                    mono_cnt <= mono_cnt + 1;
                    mono_ce <= '0';
                    
                    if mono_cnt = 6 then
                        mono_state <= '0';
                        mono_ce <= '1';
                    end if;
                end if;
            end if; -- reset_i
        end if; -- rising_edge(clk_8x_i)
    end process;

    monostable_output_p : process(clk_8x_i, mono_ce)
    begin
        if rising_edge(clk_8x_i) and mono_ce = '1' then
            coarse_counter <= coarse_counter_i;
            fine_counter   <= fine_counter_i;
            valid          <= valid_i;
        end if;
    end process;

    resync_p : process(clk_1x_i)
    begin
        if rising_edge(clk_1x_i) then
            if reset_i = '1' then
                coarse_counter_o <= "000";
                fine_counter_o   <= "000000000";
                valid_o          <= '0';
            else
                coarse_counter_o <= coarse_counter;
                fine_counter_o   <= fine_counter;
                valid_o          <= valid;
            end if; -- reset_i
        end if; -- rising_edge(clk_1x_i)
    end process;

end behavioral;

-- vim: set expandtab tabstop=4 shiftwidth=4:

