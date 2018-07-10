----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    calibration_pulse_generator - xilinx_virtex6
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This entity generates a signal used for the internal calibration of the delay 
-- line. It is constructed around a LFSR clocked by the internal ring oscillator 
-- of the FPGA (received from the STARTUP_VIRTEX6 primitive). As such, it is not 
-- correlated to the (external) system clock.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity calibration_pulse_generator is
	port ( 
		pulse_o : out std_logic );
end calibration_pulse_generator;

architecture xilinx_virtex6 of calibration_pulse_generator is

	signal clk : std_logic;
    -- We define the "ring oscillator clock" here.
	attribute PERIOD : string;
	attribute PERIOD of clk : signal is "10ns";
	
	signal ce_shift_reg : std_logic_vector(24 downto 0) := x"000000" & '1';
	signal slow_ce : std_logic;
	
	signal pulse_shift_reg : std_logic_vector(30 downto 0) := (others => '0');

begin

	clk_gen : STARTUP_VIRTEX6
	generic map (
		PROG_USR => FALSE )
	port map ( 
		CFGCLK => open,
		CFGMCLK => clk, 
		DINSPI => open,
		EOS => open,
		PREQ => open,
		TCKSPI => open,
		CLK => '0',
		GSR => '0',
		GTS => '0',
		KEYCLEARB => '1',
		PACK => '0',
		USRCCLKO => '0',
		USRCCLKTS => '0',
		USRDONEO => '0',
		USRDONETS => '0' );

    -- Divide the initial clock through CE
	slow_ce_gen : process (clk)
	begin
		if rising_edge(clk) then
			ce_shift_reg <= ce_shift_reg(23 downto 0) & ce_shift_reg(24);
		end if;
	end process;
    slow_ce <= ce_shift_reg(24);

    -- LFSR
	pulse_o_gen : process (clk, slow_ce)
	begin
		if rising_edge(clk) and slow_ce = '1' then
			pulse_shift_reg <= pulse_shift_reg(29 downto 0) & (pulse_shift_reg(27) xnor pulse_shift_reg(30));
		end if;
	end process;
	pulse_o <= pulse_shift_reg(30);

end xilinx_virtex6;

--architecture xilinx_7series of calibration_pulse_generator is
--
--	signal clk : std_logic;
--	
--	signal ce_shift_reg : std_logic_vector(24 downto 0) := x"000000" & '1';
--	signal slow_ce : std_logic;
--	
--	signal pulse_shift_reg : std_logic_vector(30 downto 0) := (others => '0');
--
--begin
--
--	clk_gen : STARTUPE2
--	generic map ( 
--		PROG_USR => "FALSE",
--		SIM_CCLK_FREQ => 0.0 ) 
--	port map ( 
--		CFGCLK => open,
--		CFGMCLK => clk,
--		EOS => open,
--		PREQ => open,
--		CLK => '0',
--		GSR => '0',
--		GTS => '0',
--		KEYCLEARB => '1',
--		PACK => '0',
--		USRCCLKO => '0',
--		USRCCLKTS => '0',
--		USRDONEO => '0',
--		USRDONETS => '0' );
--
--	slow_ce_gen : process (clk)
--	begin
--		if rising_edge(clk) then
--			ce_shift_reg <= ce_shift_reg(23 downto 0) & ce_shift_reg(24);
--		end if;
--	end process;
--    slow_ce <= ce_shift_reg(24);
--
--	pulse_o_gen : process (clk, slow_ce)
--	begin
--		if rising_edge(clk) and slow_ce = '1' then
--			pulse_shift_reg <= pulse_shift_reg(29 downto 0) & (pulse_shift_reg(27) xnor pulse_shift_reg(30));
--		end if;
--	end process;
--	pulse_o <= pulse_shift_reg(30);
--
--end xilinx_7series;
