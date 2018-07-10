----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    onehot_decoder_256 - behavioral
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This module converts a 256 bits vector in one-hot encoding to a unsigned 
-- number of 8 bits in 3 clocks cycles. It only uses OR gates with a maximum of
-- logic depth of 2 LUTs.
--
-- The first stage divides the vector in 16 smaller vectors of 16 bits where the 
-- conversion is done. We also keep the LSB.
-- For MSBs :
--   - The result of each block is OR'ed in the second stage.
--   - We use once more the 16 bits decoder on this result to get the MSBs.
-- For LSBs :
--   - We or'd the "correct bits" in two stages. The "correct bits" are the ones 
--     which where OR'ed the same way in the first stage.
-- 
-- Schematically for 16 bits :
--       15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
-- out 3  x  x  x  x  x  x  x  x 
-- out 2  x  x  x  x              x  x  x  x
-- out 1  x  x        x  x        x  x        x  x
-- out 0  x     x     x     x     x     x     x     x
--
-- It is easily extended for more bits.
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity onehot_decoder_256 is
	port (
		clk_i   : in std_logic;
        
		din_i  : in std_logic_vector(255 downto 0);
		dout_o : out unsigned(7 downto 0) );
end entity;

architecture behavioral of onehot_decoder_256 is

    function onehot_decoder_16(din : std_logic_vector (15 downto 0))
        return std_logic_vector
    is
        variable tmp : std_logic_vector(4 downto 0) := "00000";
    begin
    	tmp(4) := din(8) or din(9) or din(10) or din(11) or din(12) or din(13) or din(14) or din(15);
		tmp(3) := din(4) or din(5) or din(6)  or din(7)  or din(12) or din(13) or din(14) or din(15);
		tmp(2) := din(2) or din(3) or din(6)  or din(7)  or din(10) or din(11) or din(14) or din(15);
		tmp(1) := din(1) or din(3) or din(5)  or din(7)  or din(9)  or din(11) or din(13) or din(15);
		tmp(0) := din(0);
        return tmp;
    end function;

    type stage0_t is array(15 downto 0) of std_logic_vector(4 downto 0);
    signal stage0 : stage0_t;
    
    signal stage1_or : std_logic_vector(15 downto 0);
	type stage1_t is array(3 downto 0) of std_logic_vector(2 downto 0);
	signal stage1 : stage1_t;
    
begin

    -------------
    -- Stage 0 --
    -------------
    stage0_gen: for I in 15 downto 0 generate
        stage0_p: process(clk_i)
        begin
            if rising_edge(clk_i) then
                stage0(I) <= onehot_decoder_16(din_i(16*(I+1)-1 downto 16*I));
            end if; -- rising_edge(clk_i)
        end process;
    end generate;

    -------------
    -- Stage 1 --
    -------------
    stage1_msb_gen: for I in 15 downto 0 generate
        stage1_msb_p: process(clk_i)
		begin
			if rising_edge(clk_i) then
                stage1_or(I) <= stage0(I)(4) or stage0(I)(3) or stage0(I)(2) or stage0(I)(1) or stage0(I)(0);
			end if; -- rising_edge(clk_i)
		end process;
    end generate;
    
    stage1_lsb_gen : for I in 4 downto 1 generate
	begin
		stage1_lsb_p : process(clk_i)
		begin
			if rising_edge(clk_i) then
                stage1(I-1)(0) <= stage0(0)(I)  or stage0(1)(I)  or stage0(2)(I)  or stage0(3)(I)  or stage0(4)(I);
                stage1(I-1)(1) <= stage0(5)(I)  or stage0(6)(I)  or stage0(7)(I)  or stage0(8)(I)  or stage0(9)(I) or stage0(10)(I);
                stage1(I-1)(2) <= stage0(11)(I) or stage0(12)(I) or stage0(13)(I) or stage0(14)(I) or stage0(15)(I);
			end if; -- rising_edge(clk_i)
		end process;
    end generate;
    
    -------------
    -- Stage 2 --
    -------------
    stage2_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            -- MSBs
            dout_o(7 downto 4) <= unsigned(onehot_decoder_16(stage1_or)(4 downto 1));
            
            -- LSBs
            for I in 3 downto 0 loop
                dout_o(I) <= stage1(I)(0) or stage1(I)(1) or stage1(I)(2);
            end loop;
        end if; -- rising_edge(clk_i)
    end process;
	
end architecture;
