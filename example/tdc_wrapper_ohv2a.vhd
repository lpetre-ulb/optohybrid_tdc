----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Laurent Pétré
-- 
-- Module Name:    tdc_wrapper_ohv2a - behavioral 
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
--
-- Description: 
--
-- This module adapts the OH signals to be understood by the TDC module. Mainly,
-- it provides a Wishbone like communication for the configuration and readout.
--
-- The reset bit in the configuration register has not effect on the Wishbone 
-- communication subsystem. Moreover, the calibration LUT is not reset and could 
-- be corrupted if the calibration was in progress. It is therefore recommended 
-- to launch a calibration once the reset is finished.
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.wb_pkg.all;

entity tdc_wrapper_ohv2a is
    port(
        -- Clocks
        ref_clk_i : in std_logic;
        clk_8x_i  : in std_logic;

        -- Wishbone slave
        wb_slv_req_i : in wb_req_t;
        wb_slv_res_o : out wb_res_t;  

        -- Inputs
        trigger_i   : in std_logic;
        sbits_i     : in sbits_array_t(23 downto 0);
        sbit_mask_i : in std_logic_vector(23 downto 0) );
end entity;

architecture behavioral of tdc_wrapper_ohv2a is

    -- Wishbone signals
    constant SIZE  : integer := 32;

    signal wb_stb  : std_logic_vector(SIZE-1 downto 0);
    signal wb_we   : std_logic;
    signal wb_addr : std_logic_vector(31 downto 0);
    signal wb_recv : std_logic_vector(31 downto 0);
    signal wb_ack  : std_logic_vector(SIZE-1 downto 0);
    signal wb_err  : std_logic_vector(SIZE-1 downto 0);
    signal wb_send : std32_array_t(SIZE-1 downto 0);

    -- Command/status signals
    constant COMMAND_STATUS_ADDR : integer := 0;

    signal reset       : std_logic := '0';
    signal resetting   : std_logic := '0';
    signal calibrate   : std_logic := '0';
    signal calibrating : std_logic := '0';

    -- Window signals
    constant WINDOW_ADDR : integer := 1;

    signal window_reg  : std32_array_t(1 downto 0) := (others => (others => '0'));
    signal window_mask : std_logic_vector(255 downto 0) := (others => '0');

    -- Calibration signals
    constant CALIB_ADDR : integer := 3;

    signal callut_addr : unsigned(8 downto 0) := "000000000";
    signal callut_data : std_logic_vector(11 downto 0) := (others => '0');

    -- Packet signals
    constant PACKET_ADDR : integer := 8;

    -- Input signals
    signal sbits_or : std_logic_vector(23 downto 0) := (others => '0');

begin

    -----------------
    -- WB splitter --
    -----------------
    wb_splitter_inst : entity work.wb_splitter
    generic map(
        SIZE   => SIZE,
        OFFSET => 0
    )
    port map(
        ref_clk_i => ref_clk_i,
        reset_i   => '0',
        wb_req_i  => wb_slv_req_i,
        wb_res_o  => wb_slv_res_o,
        
        stb_o  => wb_stb,
        we_o   => wb_we,
        addr_o => wb_addr,
        data_o => wb_recv,
        ack_i  => wb_ack,
        err_i  => wb_err,
        data_i => wb_send );

    --------------------
    -- Command/status --
    --------------------
    command_status_p : process(ref_clk_i)
    begin
        if rising_edge(ref_clk_i) then
            reset     <= '0';
            calibrate <= '0';

            wb_ack(COMMAND_STATUS_ADDR)  <= '0';
            wb_err(COMMAND_STATUS_ADDR)  <= '0';
            wb_send(COMMAND_STATUS_ADDR) <= (31 downto 2 => '0') & calibrating & resetting;
                        
            if wb_stb(COMMAND_STATUS_ADDR) = '1' then
                wb_ack(COMMAND_STATUS_ADDR) <= '1';
                
                if wb_we = '1' then
                    reset     <= wb_recv(0);
                    calibrate <= wb_recv(1);
                end if;
            end if;
        end if;
    end process;

    -------------
    --  Window --
    -------------
    window_reg_gen : for I in 0 to 1 generate
        window_reg_p : process(ref_clk_i)
        begin
            if (rising_edge(ref_clk_i)) then
                wb_ack(I+WINDOW_ADDR)  <= '0';
                wb_err(I+WINDOW_ADDR)  <= '0';
                wb_send(I+WINDOW_ADDR) <= window_reg(I);

                if wb_stb(I+WINDOW_ADDR) = '1' then
                    wb_ack(I+WINDOW_ADDR) <= '1';
                    if (wb_we = '1') and (reset = '0') then
                        window_reg(I) <= wb_recv;
                    end if;
                end if;
                
                if reset = '1' then
                    window_reg(I) <= (others => '0');
                end if;
            end if;
        end process;
    end generate;

    window_gen : for I in 0 to 31 generate
    begin
        window_mask(I*4)       <= window_reg(0)(I);
        window_mask(I*4 + 1)   <= window_reg(0)(I);
        window_mask(I*4 + 2)   <= window_reg(0)(I);
        window_mask(I*4 + 3)   <= window_reg(0)(I);
        window_mask(I*4 + 128) <= window_reg(1)(I);
        window_mask(I*4 + 129) <= window_reg(1)(I);
        window_mask(I*4 + 130) <= window_reg(1)(I);
        window_mask(I*4 + 131) <= window_reg(1)(I);
    end generate;


    ----------------------
    --  Calibration LUT --
    ----------------------
    process(ref_clk_i)
    begin
        if rising_edge(ref_clk_i) then
            wb_ack(CALIB_ADDR) <= '0';
            wb_err(CALIB_ADDR) <= '0';
            
            if wb_stb(CALIB_ADDR) = '1' then
                wb_ack(CALIB_ADDR) <= '1';

                if (wb_we = '1') then
                    callut_addr <= "000000000";
                else
                    callut_addr <= callut_addr + 1;
                end if;
            end if;
        end if;
    end process;

    wb_send(CALIB_ADDR)(31 downto 12) <= (others => '0');
    wb_send(CALIB_ADDR)(11 downto 0)  <= callut_data;
    
    -------------
    --  Inputs --
    -------------
    sbits_or_gen : for I in 0 to 23 generate
        sbits_or_p : process(ref_clk_i)
        begin
            if (rising_edge(ref_clk_i)) then
                sbits_or(I) <= sbits_i(I)(0) or sbits_i(I)(1) or sbits_i(I)(2) or sbits_i(I)(3) 
                                 or sbits_i(I)(4) or sbits_i(I)(5) or sbits_i(I)(6) or sbits_i(I)(7);
            end if;
        end process;
    end generate;

    ---------
    -- TDC --
    ---------
    tdc_inst : entity work.tdc
    port map(
        clk_1x_i => ref_clk_i,
        clk_8x_i => clk_8x_i,

        reset_i       => reset,
        resetting_o   => resetting,
        calibrate_i   => calibrate,
        calibrating_o => calibrating,

        window_mask_i => window_mask,
        vfat_mask_i   => sbit_mask_i,

        trigger_i   => trigger_i,
        sbits_i     => sbits_or,

        fifo_rden      => wb_stb(PACKET_ADDR + 23 downto PACKET_ADDR),
        fifo_dout      => wb_send(PACKET_ADDR + 23 downto PACKET_ADDR),
        fifo_valid     => wb_ack(PACKET_ADDR + 23 downto PACKET_ADDR),
        fifo_underflow => wb_err(PACKET_ADDR + 23 downto PACKET_ADDR),

        callut_addr_i => std_logic_vector(callut_addr),
        callut_data_o => callut_data );

end behavioral;

-- vim: set expandtab tabstop=4 shiftwidth=4:

