----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    tdc - behavioral 
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This entity instanciates a TDC channel for the external trigger and the sbits
-- delay lines for the 24 VFATs.
--
-- All signals are sampled by 'clk_1x_i'. The 'clk_8x_i' clock must be in phase 
-- with the 'clk_1x_i' clock. The 'trigger_i' input is asynchronous.
--
-- Note that the calibration LUT is not reset after asserting 'reset_i' and could 
-- even be corrupted if the calibration was in progress. It is therefore recommended 
-- to launch a calibration once the reset is finished.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;

entity tdc is
    generic (
        g_LOC_X : integer := 64;
		g_LOC_Y : integer := 60 );
    port (
        -- Clocks
        clk_1x_i : in std_logic;
        clk_8x_i : in std_logic;

        -- Config
        reset_i       : in std_logic;
        resetting_o   : out std_logic;

        calibrate_i   : in std_logic;
        calibrating_o : out std_logic;

        window_mask_i : in std_logic_vector(255 downto 0);
        vfat_mask_i   : in std_logic_vector(23 downto 0);            

        -- Inputs
        trigger_i   : in std_logic;
        sbits_i     : in std_logic_vector(23 downto 0);

        -- FIFOs
        fifo_rden      : in std_logic_vector(23 downto 0);
        fifo_dout      : out std32_array_t(23 downto 0);
        fifo_valid     : out std_logic_vector(23 downto 0);
        fifo_underflow : out std_logic_vector(23 downto 0);
        
        -- Calibration LUT
        callut_addr_i : in std_logic_vector(8 downto 0);
        callut_data_o : out std_logic_vector(11 downto 0) );
end entity;

architecture behavioral of tdc is

    -- Reset signals    
    signal reset_sr  : std_logic_vector(9 downto 0) := (others => '0');
    signal reset     : std_logic := '0';

    -- TDC signals
    signal calib_pulse      : std_logic := '0';
    signal tdc_en           : std_logic := '1';
    signal calib_sel        : std_logic := '0';
	signal tdc_fine_counter : std_logic_vector(8 downto 0) := "000000000";
    signal tdc_valid        : std_logic := '0';
    
    -- CDC signals
    signal tdc_coarse_counter_resync : std_logic_vector(2 downto 0) := "000";
    signal tdc_fine_counter_resync   : std_logic_vector(8 downto 0) := "000000000";
    signal tdc_valid_resync          : std_logic := '0';

    -- Calibration signals
    signal calib_done : std_logic := '1';
    
    signal tdc_coarse_counter_resync_d1 : std_logic_vector(2 downto 0) := "000";
    signal calib_coarse_counter         : std_logic_vector(2 downto 0) := "000";
    signal calib_fine_time              : std_logic_vector(11 downto 0) := "000000000000";
    signal calib_valid                  : std_logic := '0';

    -- Sbits signals
    type sbits_position_t is array(23 downto 0) of std_logic_vector(7 downto 0);
    signal sbits_position : sbits_position_t;
    signal sbits_valid : std_logic_vector(23 downto 0);

    -- Packet signals
    type packet_t is array(23 downto 0) of std_logic_vector(31 downto 0);
    signal packet : packet_t;
    signal packet_we : std_logic_vector(23 downto 0);

begin

    -----------
    -- Reset --
    -----------
    reset_p : process(clk_1x_i)
    begin
        if rising_edge(clk_1x_i) then
            reset_sr(reset_sr'left) <= '0';
            reset_sr(reset_sr'left - 1 downto 0) <= reset_sr(reset_sr'left downto 1);

            if reset_i = '1' then
                    reset_sr  <= (others => '1');
            end if;
        end if;
    end process;

    reset       <= reset_sr(0);
    resetting_o <= reset;

	-----------------
	-- TDC channel --
	-----------------
    calib_pulse_gen_inst : entity work.calibration_pulse_generator(xilinx_virtex6)
	port map (
		pulse_o => calib_pulse );
    
	tdc_channel_inst: entity work.tdc_channel
	generic map (
		g_LOC_X => g_LOC_X,
		g_LOC_Y => g_LOC_Y )
	port map (
		clk_i   => clk_8x_i,
        reset_i => reset,
        
		in_a_i    => trigger_i,
        calib_a_i => calib_pulse,
        
        en_a_i        => tdc_en,
        calib_sel_a_i => calib_sel,
		
		valid_o                          => tdc_valid,
		std_logic_vector(fine_counter_o) => tdc_fine_counter );
    
    --------------------
    -- TDC output CDC --
    --------------------
    tdc_cdc_inst : entity work.tdc_cdc
    port map (
        clk_1x_i => clk_1x_i,
        clk_8x_i => clk_8x_i,
        reset_i  => reset,
        
        fine_counter_i => tdc_fine_counter,
        valid_i        => tdc_valid,
        
        coarse_counter_o => tdc_coarse_counter_resync,
        fine_counter_o   => tdc_fine_counter_resync,
        valid_o          => tdc_valid_resync
    );
    
    -----------------
	-- Calibration --
	-----------------
    calibration_inst : entity work.calibration
    port map (
        clk_i   => clk_1x_i,
        reset_i => reset,
        
        fine_counter_i => tdc_fine_counter_resync,
        valid_i        => tdc_valid_resync,

        fine_time_o => calib_fine_time,
        valid_o     => calib_valid,

        calibrate_i       => calibrate_i,
        need_calib_data_o => calib_sel,
        done_o            => calib_done,

        callut_addr_i => callut_addr_i,
        callut_data_o => callut_data_o );
    
    calibrating_o <= not calib_done;
    
    -- The coarse counter is not sent to the calibration entity, but
    -- must be delayed to take into account the latency induced by the
    -- conversion from fine_counter to a timestamp.
    delay_coarse_counter_p : process(clk_1x_i)
    begin
        if rising_edge(clk_1x_i) then
            if reset = '1' then
                tdc_coarse_counter_resync_d1 <= (others => '0');
                calib_coarse_counter         <= (others => '0');
            else
                tdc_coarse_counter_resync_d1 <= tdc_coarse_counter_resync;
                calib_coarse_counter         <= tdc_coarse_counter_resync_d1;
            end if;
        end if;
    end process;
    
    ---------------
    -- Per VFATs --
    ---------------
    per_vfat_gen : for I in 0 to 23 generate
    begin
        -- Delays --
        sbits_delay_inst : entity work.sbits_delay
        port map (
            clk_i   => clk_1x_i,
            reset_i => reset,
            
            sbits_i       => sbits_i(I),
            window_mask_i => window_mask_i,
            
            position_o    => sbits_position(I),
            valid_o       => sbits_valid(I)
        );
        
        -- Create packet
        process(clk_1x_i)
        begin
            if rising_edge(clk_1x_i) then
                if reset = '1' then
                    packet(I)    <= (others => '0');
                    packet_we(I) <= '0';
                else
                    packet(I) <= "00000000" & sbits_valid(I) & sbits_position(I) & calib_coarse_counter & calib_fine_time;
                    
                    if calib_valid = '1' and vfat_mask_i(I) = '0' then
                        packet_we(I) <= '1';
                    else
                        packet_we(I) <= '0';
                    end if;
                end if; -- reset
            end if; -- rising_edge(clk_1x_i)
        end process;
        
        -- FIFOs --
        fifo_inst : entity work.fifo512x32
		port map (
            clk => clk_1x_i,
			rst => reset,
            
            wr_en => packet_we(I),
            din   => packet(I),
            full  => open,
			
			rd_en     => fifo_rden(I),
			dout      => fifo_dout(I),
            valid     => fifo_valid(I),
			underflow => fifo_underflow(I),
            empty     => open
		);
    end generate;

end architecture;
