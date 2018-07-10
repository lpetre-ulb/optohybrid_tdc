----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    sbits_delay - behavioral
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This module lets to know the time of arrival of the oldest sbit of a single VFAT
-- within a given window, 'window_mask_i'.
-- It is designed around a shift register fed by the OR of the sbits of a VFAT. The
-- outputs of the shift register are AND'ed with the window and then sent to a 
-- priority encoder which gives the position of the oldest sbit present in that 
-- shift register.
-- While the usable shift register length is fixed at 256 elements, the g_LATENCY 
-- parameter allows to extend between its input and the first used output.
--
--      +-+   +-+   +-+   +-+   +-+   +-+   +-+   +-+   
-- OR-->+D+-->+D+-->+D+-->+D+-->+D+-->+D+-->+D+-->+D+-->
--      +-+   +-+   +-+   +-+ | +-+ | +-+ | +-+ | +-+ |
--     \__ g_LATENCY=3 __/    v     v     v     v     v 
--                           +----- Window and PE -----+
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sbits_delay is
    generic (
        g_LATENCY : integer := 2 );
    port ( 
        clk_i   : in std_logic;
        reset_i : in std_logic;
        
        sbits_i       : in std_logic;
        window_mask_i : in std_logic_vector(255 downto 0);
        
        position_o : out std_logic_vector(7 downto 0);
        valid_o    : out std_logic );
end entity;

architecture behavioral of sbits_delay is

    -- This function is a priotity encoder of 256 bits with the LSB having
    -- the highest priority (and the value 0). Its output is a vector of 9
    -- bits : the valid bit and 8 bits for the position. 
    function priority256(input : std_logic_vector(255 downto 0))
        return std_logic_vector
    is
        type pos_s0_t is array(127 downto 0) of std_logic_vector(0 downto 0);
        variable pos_s0 : pos_s0_t;
        variable out_s0 : std_logic_vector(127 downto 0);
        
        type pos_s1_t is array(63 downto 0) of std_logic_vector(1 downto 0);
        variable pos_s1 : pos_s1_t;
        variable out_s1 : std_logic_vector(63 downto 0);
        
        type pos_s2_t is array(31 downto 0) of std_logic_vector(2 downto 0);
        variable pos_s2 : pos_s2_t;
        variable out_s2 : std_logic_vector(31 downto 0);
        
        type pos_s3_t is array(15 downto 0) of std_logic_vector(3 downto 0);
        variable pos_s3 : pos_s3_t;
        variable out_s3 : std_logic_vector(15 downto 0);
        
        type pos_s4_t is array(7 downto 0) of std_logic_vector(4 downto 0);
        variable pos_s4 : pos_s4_t;
        variable out_s4 : std_logic_vector(7 downto 0);
        
        type pos_s5_t is array(3 downto 0) of std_logic_vector(5 downto 0);
        variable pos_s5 : pos_s5_t;
        variable out_s5 : std_logic_vector(3 downto 0);
        
        type pos_s6_t is array(1 downto 0) of std_logic_vector(6 downto 0);
        variable pos_s6 : pos_s6_t;
        variable out_s6 : std_logic_vector(1 downto 0);
        
        -- Outputs
        variable pos_out : std_logic_vector(7 downto 0);
        variable valid   : std_logic;
    begin
        for I in 127 downto 0 loop
            pos_s0(I) := "0" when input(2*I) = '1' else "1";
            out_s0(I) := input(2*I) or input(2*I + 1);
        end loop;
        
        for I in 63 downto 0 loop
            pos_s1(I) := '0' & pos_s0(2*I) when out_s0(2*I) = '1' else '1' & pos_s0(2*I+1);
            out_s1(I) := out_s0(2*I) or out_s0(2*I + 1);
        end loop;
        
        for I in 31 downto 0 loop
            pos_s2(I) := '0' & pos_s1(2*I) when out_s1(2*I) = '1' else '1' & pos_s1(2*I+1);
            out_s2(I) := out_s1(2*I) or out_s1(2*I + 1);
        end loop;
        
        for I in 15 downto 0 loop
            pos_s3(I) := '0' & pos_s2(2*I) when out_s2(2*I) = '1' else '1' & pos_s2(2*I+1);
            out_s3(I) := out_s2(2*I) or out_s2(2*I + 1);
        end loop;
        
        for I in 7 downto 0 loop
            pos_s4(I) := '0' & pos_s3(2*I) when out_s3(2*I) = '1' else '1' & pos_s3(2*I+1);
            out_s4(I) := out_s3(2*I) or out_s3(2*I + 1);
        end loop;
        
        for I in 3 downto 0 loop
            pos_s5(I) := '0' & pos_s4(2*I) when out_s4(2*I) = '1' else '1' & pos_s4(2*I+1);
            out_s5(I) := out_s4(2*I) or out_s4(2*I + 1);
        end loop;
        
        for I in 1 downto 0 loop
            pos_s6(I) := '0' & pos_s5(2*I) when out_s5(2*I) = '1' else '1' & pos_s5(2*I+1);
            out_s6(I) := out_s5(2*I) or out_s5(2*I + 1);
        end loop;
        
        pos_out := '0' & pos_s6(0) when out_s6(0) = '1' else '1' & pos_s6(1);
        valid := out_s6(0) or out_s6(1);
        
        return valid & pos_out;
    end function;
    
    -- This function reverse a std_logic_vector
    function reverse_vector(input: std_logic_vector)
        return std_logic_vector
    is
        variable tmp : std_logic_vector(input'range);
    begin
        for I in input'range loop
            tmp(I) := input(input'left - I);
        end loop;
        return tmp;
    end function;
    
    -- Shift register signals
    signal delayed_or : std_logic_vector(255 + g_LATENCY downto 0) := (others => '0');
    
begin

    shift_reg_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                delayed_or <= (others => '0');
            else
                delayed_or(delayed_or'left) <= sbits_i;
                delayed_or(delayed_or'left-1 downto 0) <= delayed_or(delayed_or'left downto 1);
            end if; -- reset_i
        end if; -- rising_edge(clk_i)
    end process;
    
    output_p : process(clk_i)
        variable windowed : std_logic_vector(255 downto 0);
        variable output   : std_logic_vector(8 downto 0);
    begin
        windowed := delayed_or(255 downto 0) and reverse_vector(window_mask_i);
        output   := priority256(windowed);
        
        if rising_edge(clk_i) then
                position_o <= output(7 downto 0);
                valid_o    <= output(8);
        end if;
    end process;

end behavioral;
