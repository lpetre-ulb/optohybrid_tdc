----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    tdc_delay_line - rtl
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This module is a delay line composed by CARRY4. A postive pulse of 
-- g_PULSE_LENGTH taps is launched when 'in_i' rises. The delay line length is
-- defined by g_TAPS. As is should be placed as close a possible from the input
-- pin, we can place it with g_LOC_X and g_LOX_Y.
-- Only 2 outputs of a CARRY4 are used. It allows a longer delay line for the same 
-- number of taps and avoid empty delays due to routing. Therefore, the number of 
-- CARRY4 primitives used is half of g_TAPS.
-- The last setting is g_VALID_DISTANCE which defines the position of the valid
-- flip-flop. It must be placed far enough to have the time for the pulse to be 
-- launched.
-- The default settings work on target device.
-- WARNING : taps_o can contain "bubbles" and valid_o is asserted more than one 
-- cycle. Only the first cycle is valid and it always returns to 0 between to 
-- events. However, there two flip-flop rows to prevent metastability.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity tdc_delay_line is
	generic (
		g_TAPS           : integer := 256;
        g_PULSE_LENGTH   : integer := 8;
		g_LOC_X          : integer := 0;
		g_LOC_Y          : integer := 0;
        g_VALID_DISTANCE : integer := 18 );
	port (
		clk_i   : in std_logic;
        reset_i : in std_logic;
		
		in_i : in std_logic;
		
		taps_o  : out std_logic_vector(g_TAPS-1 downto 0);
		valid_o : out std_logic );
end entity;

architecture rtl of tdc_delay_line is

    signal launch_clr   : std_logic := '0';
	signal launch       : std_logic := '0';
	signal launch_delay : std_logic_vector(2*g_TAPS-1 downto 0) := (others => '1');
	
	signal taps_carry_ff : std_logic_vector(2*g_TAPS-1 downto 0) := (others => '0');
    signal taps_ff_ff    : std_logic_vector(g_TAPS-1 downto 0) := (others => '0');
    
	signal valid_ff_ff : std_logic := '0';
    signal valid       : std_logic := '0';

	-- Avoid optimisations (synth and P&R)
	attribute DONT_TOUCH : string;
	attribute DONT_TOUCH of rtl : architecture is "true";
	attribute KEEP_HIERARCHY : string;
	attribute KEEP_HIERARCHY of rtl : architecture is "true";

	-- Place all components
	attribute RLOC_ORIGIN : string;
	attribute RLOC_ORIGIN of delay0 : label is "X" & integer'image(g_LOC_X) & "Y" & integer'image(g_LOC_Y);
	
	attribute RLOC : string;
    attribute RLOC of launch_clr_LUT : label is "X2Y" & integer'image(((2*g_PULSE_LENGTH)+3)/4);
	attribute RLOC of launch_FDCE    : label is "X2Y" & integer'image(((2*g_PULSE_LENGTH)+3)/4);
	attribute RLOC of delay0         : label is "X0Y0";
	attribute RLOC of valid_ff1      : label is "X2Y" & integer'image(((2*g_PULSE_LENGTH)+3)/4 + g_VALID_DISTANCE);
	attribute RLOC of valid_ff2      : label is "X2Y1";

begin

	------------
	-- Launch --
	------------
    launch_clr_LUT : LUT2
    generic map (
        INIT => "1110" )
    port map (
        I0 => valid,
        I1 => reset_i,
        O  => launch_clr );
    
	launch_FDCE : FDCE
	generic map (
		INIT => '0')
	port map (
		D   => '1',
		Q   => launch,
		C   => in_i,
		CE  => '1',
		CLR =>  launch_clr );
        
    launch_delay_gen: for I in 0 to 2*g_TAPS-1 generate
	begin
        launch_delay_position: if I = 0 or I = 2*g_PULSE_LENGTH generate
            launch_delay(I) <= launch;
        end generate;
	end generate;

	------------
	-- Delays --
	------------
	delay0: CARRY4
	port map (
		CO     => taps_carry_ff(3 downto 0),
		CI     => '0',
		CYINIT => '0',
		DI     => "1111",
		S      =>  launch_delay(3 downto 0) );

	delays_gen: for I in 1 to g_TAPS/2-1 generate
		attribute RLOC of delay : label is "X0Y" & integer'image(I);
	begin
		delay: CARRY4
		port map(
			CO     => taps_carry_ff(4*(I+1)-1 downto 4*I),
			CI     => taps_carry_ff(4*I-1),
			CYINIT => '0',
			DI     => "0000",
			S      => launch_delay(4*(I+1)-1 downto 4*I) );
	end generate;

	--------------------
	-- FFs for delays --
	--------------------
	ffs: for I in 0 to g_TAPS-1 generate
		attribute RLOC of ff1 : label is "X0Y" & integer'image(I/2);
		attribute RLOC of ff2 : label is "X1Y" & integer'image(I/2);
	begin
		ff1: FDRE
		generic map (
			INIT => '0' )
		port map (
			D  => taps_carry_ff(2*I),
			Q  => taps_ff_ff(I),
			C  => clk_i,
			CE => '1',
			R  => '0' );
			
		ff2: FDRE
		generic map (
			INIT => '0' )
		port map (
			D  => taps_ff_ff(I),
			Q  => taps_o(I),
			C  => clk_i,
			CE => '1',
			R  => '0' );
	end generate;

	---------------
	-- Valid bit --
	---------------
	valid_ff1: FDRE
	generic map (
		INIT => '0' )
	port map (
		D  => launch,
		Q  => valid_ff_ff,
		C  => clk_i,
		CE => '1',
		R  => '0' );
	
	valid_ff2: FDRE
	generic map (
		INIT => '0' )
	port map (
		D  => valid_ff_ff,
		Q  => valid,
		C  => clk_i,
		CE => '1',
		R  => '0' );
        
    valid_o <= valid;

end architecture;
