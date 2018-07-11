----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    coarse_counter - behavorial
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This is a 3 bits counter running at 'clk_8x_i' and aligned with 'clk_4x_i'. The 
-- 'counter_o' thus gives the number of 'clk_8x_i' clock cycles minus 1 since the 
-- last 'clk_1x_i' rising edge.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity coarse_counter is
    port ( 
        clk_1x_i : in std_logic;
        clk_8x_i : in std_logic;
        reset_i  : in std_logic;
        
        counter_o : out std_logic_vector(2 downto 0) );
end coarse_counter;

architecture behavioral of coarse_counter is

    type state_t is (RESET, NORMAL);
    signal state : state_t := RESET;

    signal counter : unsigned(2 downto 0) := "000";

begin

    process(clk_1x_i)
    begin
        if rising_edge(clk_1x_i) then
            if reset_i = '1' then
                state <= RESET;
            else
                state <= NORMAL;
            end if;
        end if;
    end process;

    process(clk_8x_i)
    begin
        if rising_edge(clk_8x_i) then
            if state = RESET then
                counter <= "000";
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    counter_o <= std_logic_vector(counter);

end behavioral;

-- vim: set expandtab tabstop=4 shiftwidth=4:

