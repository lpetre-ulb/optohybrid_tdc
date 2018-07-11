----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    tdc_channel - behavioral
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This module instanciates a channel of TDC based on the delay line. It shapes 
-- the raw output and converts it to unsigned number representing the progression 
-- of the pulse in the delay line.
-- The generics are those used in the 'tdc_delay_line' entity.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity tdc_channel is
    generic (
        g_TAPS           : integer := 256;
        g_PULSE_LENGTH   : integer := 8;
        g_LOC_X          : integer := 0;
        g_LOC_Y          : integer := 0;
        g_VALID_DISTANCE : integer := 18 );
    port (
        clk_i   : in std_logic;
        reset_i : in std_logic;

        in_a_i    : in std_logic;
        calib_a_i : in std_logic;

        en_a_i        : in std_logic;
        calib_sel_a_i : in std_logic;

        fine_counter_o : out unsigned(8 downto 0);
        valid_o        : out std_logic );
end entity;

architecture behavioral of tdc_channel is

    -- Delay line
    signal delay_line_input : std_logic := '0';
    signal taps             : std_logic_vector(g_TAPS-1 downto 0) := (others => '0');

    -- Edges
    signal rising_edge_output  : std_logic_vector(g_TAPS-1 downto 0) := (others => '0');
    signal falling_edge_output : std_logic_vector(g_TAPS-1 downto 0) := (others => '0');

    -- Edges positions
    signal rising_edge_input  : std_logic_vector(255 downto 0) := (others => '0');
    signal falling_edge_input : std_logic_vector(255 downto 0) := (others => '0');
    signal rising_edge_cnt    : unsigned(7 downto 0) := (others => '0');
    signal falling_edge_cnt   : unsigned(7 downto 0) := (others => '0');

    -- Valid
    signal valid_ok  : std_logic := '1';
    signal valid     : std_logic := '0';
    signal valid_reg : std_logic_vector(3 downto 0) := "0000";

    -- We place the selection LUT
    attribute LOC : string;
    attribute LOC of delay_line_input_inst : label is 
        "SLICE_X" & integer'image(g_LOC_X) & "Y" & integer'image(g_LOC_Y);

    -- It is easier for P&R if valid_reg isn't a SRL16
    attribute SHREG_EXTRACT : string;
    attribute SHREG_EXTRACT of valid_reg : signal is "no";

begin

    ---------------------------
    -- Calibration selection --
    ---------------------------
    delay_line_input_inst : LUT4
    generic map (
        -- If en_a_i = '0', output = '0'
        -- else
        --   if    calib_sel_a_i = '1', output = calib_a_i
        --   elsif calib_sel_a_i = '0', output = in_a_i
        INIT => "1100101000000000"
    )
    port map (
        I0 => in_a_i,
        I1 => calib_a_i,
        I2 => calib_sel_a_i,
        I3 => en_a_i,
        O  => delay_line_input
    );

    ------------
    -- Delays --
    ------------
    tdc_delay_line_inst : entity work.tdc_delay_line
    generic map (
        g_TAPS           => g_TAPS,
        g_PULSE_LENGTH   => g_PULSE_LENGTH,
        g_LOC_X          => g_LOC_X + 1,
        g_LOC_Y          => g_LOC_Y, 
        g_VALID_DISTANCE => g_VALID_DISTANCE )
    port map (
        clk_i   => clk_i,
        reset_i => reset_i,
        in_i    => delay_line_input,
        taps_o  => taps,
        valid_o => valid );

    -----------
    -- Edges --
    -----------
    edge_detector_inst: entity work.edge_detector
    generic map (
        g_SIZE => g_TAPS )
    port map ( 
        clk_i          => clk_i,
        in_i           => taps,
        rising_edge_o  => rising_edge_output,
        falling_edge_o => falling_edge_output );

    ----------------------
    -- Onehot to binary --
    ----------------------
    rising_edge_input  <= (255 downto rising_edge_output'length  => '0') 
                            & rising_edge_output;
    falling_edge_input <= (255 downto falling_edge_output'length => '0') 
                            & falling_edge_output;

    rising_edge_decoder_inst : entity work.onehot_decoder_256
    port map (
        clk_i   => clk_i,
        din_i   => rising_edge_input,
        dout_o  => rising_edge_cnt );

    falling_edge_decoder_inst : entity work.onehot_decoder_256
    port map (
        clk_i   => clk_i,
        din_i   => falling_edge_input,
        dout_o  => falling_edge_cnt );

    ---------
    -- Sum --
    ---------
    sum_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            fine_counter_o <= ('0' & rising_edge_cnt) + ('0' & falling_edge_cnt);
        end if; -- rising_edge(clk_i)
    end process;

    -----------
    -- Valid --
    -----------
    valid_p: process(clk_i)
    begin
        if rising_edge(clk_i) then
            valid_ok <= valid_ok;
            valid_reg(0) <= '0';

            if valid_ok = '1' then
                if valid = '1' then
                    valid_ok <= '0';
                    valid_reg(0) <= valid;
                end if;
            else
                if valid = '0' then
                    valid_ok <= '1';
                end if;
            end if;

            valid_reg(3 downto 1) <= valid_reg(2 downto 0);
            valid_o <= valid_reg(3);
        end if; -- rising_edge(clk_i)
    end process;

end architecture;

-- vim: set expandtab tabstop=4 shiftwidth=4:

