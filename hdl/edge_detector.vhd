----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    edge_detector - behavioral
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This module returns the position of edges given in in_i. It is resistant to 
-- bubbles up to a length of 4 bits. g_SIZE defines the length of the in_i vector.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity edge_detector is
    generic (
        g_SIZE : integer := 256 );
    port ( 
        clk_i   : in std_logic;

        in_i : in std_logic_vector(g_SIZE-1 downto 0);

        rising_edge_o  : out std_logic_vector(g_SIZE-1 downto 0);
        falling_edge_o : out std_logic_vector(g_SIZE-1 downto 0) );
end entity;

architecture behavioral of edge_detector is

    function rising(input : std_logic_vector (4 downto 0)) return std_logic is
    begin
        return (not input(4)) and input(3) and input(2) and input(1) and input(0);
    end rising;

    function falling(input : std_logic_vector (4 downto 0)) return std_logic is
    begin
        return input(4) and input(3) and input(2) and input(1) and (not input(0));
    end falling;

begin

    rising_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            for I in 0 to g_SIZE-1 loop
                case I is
                    when 0 =>
                        rising_edge_o(I) <= rising(in_i(I) & "0000");
                    when 1 =>
                        rising_edge_o(I) <= rising(in_i(I downto I-1) & "000");
                    when 2 =>
                        rising_edge_o(I) <= rising(in_i(I downto I-2) & "00" );
                    when 3 =>
                        rising_edge_o(I) <= rising(in_i(I downto I-3) & '0' );
                    when 255 =>
                        rising_edge_o(I) <= rising('0' & in_i(I-1 downto I-4));
                    when others =>
                        rising_edge_o(I) <= rising(in_i(I downto I-4));
                end case;
            end loop;
        end if; -- rising_edge(clk_i)
    end process;

    falling_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            for I in 0 to g_SIZE-1 loop
                case I is
                    when g_SIZE-1 =>
                        falling_edge_o(I) <= falling("0000" & in_i(I));
                    when g_SIZE-2 =>
                        falling_edge_o(I) <= falling("000" & in_i(I+1 downto I));
                    when g_SIZE-3 =>
                        falling_edge_o(I) <= falling("00"  & in_i(I+2 downto I));
                    when g_SIZE-4 =>
                        falling_edge_o(I) <= falling('0'   & in_i(I+3 downto I));
                    when others =>
                        falling_edge_o(I) <= falling(in_i(I+4 downto I));
                end case;
            end loop;
        end if; -- rising_edge(clk_i)
    end process;

end architecture;

-- vim: set expandtab tabstop=4 shiftwidth=4:

