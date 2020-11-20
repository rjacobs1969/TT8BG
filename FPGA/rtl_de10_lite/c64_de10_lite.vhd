---------------------------------------------------------------------------------
-- DE10 lite Top level for FPGA64_027 by Dar (darfpga@aol.fr) 08-Mai-2019
-- http://darfpga.blogspot.fr
--
-- FPGA64 is Copyrighted 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
--
-- sdram interface is Copyright (c) 2013 Till Harbaum <till@harbaum.org>
-- from MiST/MiSTer project.
--
-- Uses only one pll for 32MHz and 18MHz generation from 50MHz
--
-- Rev 3.0 : 08 Mai 2019 
--	  added support for FAT32 SD card by using ZPUflex control_module
--   TAP and D64 loaders ok (read only)
--   updated FPGA64 form MiST source dated 30-Avril-2019 but :
--     - no ROM load
--     - no cartridge interface
--     - PAL frequency only
--	    - 15KHz TV mode only
--
--   F9 : start/stop tape on USB keyboard (to be done for PS/2)
--
--   Display leds : 
--     0-3 : spi arbitration sd card/usb host
--       6 : tape motor on = led on
--       7 : tape write (not used)
--       8 : tape version detected 1 = led on
--       9 : tap fifo underflow 1 = error (clear on TAP file select)
--
--   Keys usage:
--     key 0 : reset C64 (also thru OSD)
--     key 1 : reset control module
--
--   Swiches usage: none.
--
-- Rev 2.0 : 08 Avril 2019 - demo for c1530 only
--
-- Rev 1.2 : 24 Avril 2019 - DE10-Lite sdram release
--   removed external sram interface
--   replace with on board sdram
--   external IEC always available but commented here to avoid bus stuck.
--
--   /!\ current configuration required no gpio pin
--   /!\ arduino pins are used to interface with :
--       - SD card over SPI bus
--       - usb_host_max3421e over SPI bus shared with SD card
--       - sgtl5000 dac over digital audio bus + I2C bus for configuation
--
-- Rev 1.1 - 05_June-2017
--   Fix SDHC card lba computation in spi_controler.vhd
--
-- Rev 1.0 : 25 May 2017 - early release
--   added USB keyboard support with French layout
--   added write capability to c1541_sd

--  Main features (Rev 1.0/1.1 only)
--  15KHz(TV) / 31Khz(VGA) : board sw(0)
--  PAL(50Hz) / NTSC(60Hz) : board sw(1) and F12 key
--  PS2 keyboard input with portA / portB joystick emulation : F11 key
--  pwm sound output : board arduino(15 to 14) 
--  video output : 2 Syncs + 3x4 Colors 
--  64Ko SRAM : board gpio_0(0 to 29)
--  External IEC bus available at gpio_1 (for real drive 1541 or IEC/SD ...)
--    activated by switch(5) (activated with no hardware will stuck IEC bus)
--
--  Internal emulated 1541 on raw SD card : D64 images start at 256KB boundaries
--  Use hexidecimal disk editor such as HxD (www.mh-nexus.de) to build SD card.
--  Cut D64 file and paste at 0x00000 (first), 0x40000 (second), 0x80000 (third),
--  0xC0000(fourth), 0x100000(fith), 0x140000 (sixth) and so on.
--  BE CAREFUL NOT WRITING ON YOUR OWN HARDDRIVE
--  
-- TODO (2018 winter !) : 
--   Keyboard special key to be tested
--   SID to be replaced with better design (from 1541-II)
--   External RAM to be suppressed (many room available wihtin DE10 lite FPGA)
--   NTSC video to be fixed, PAL and, NTSC 31KHz mode to be fixed 
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.usb_report_pkg.all;

entity c64_de10_lite is
port(
 max10_clk1_50  : in std_logic;
-- max10_clk2_50  : in std_logic;
-- adc_clk_10     : in std_logic;
 ledr           : out std_logic_vector(9 downto 0);
 key            : in std_logic_vector(1 downto 0);
 sw             : in std_logic_vector(9 downto 0);

 dram_ba    : out std_logic_vector(1 downto 0);
 dram_ldqm  : out std_logic;
 dram_udqm  : out std_logic;
 dram_ras_n : out std_logic;
 dram_cas_n : out std_logic;
 dram_cke   : out std_logic;
 dram_clk   : out std_logic;
 dram_we_n  : out std_logic;
 dram_cs_n  : out std_logic;
 dram_dq    : inout std_logic_vector(15 downto 0);
 dram_addr  : out std_logic_vector(12 downto 0);

-- hex0 : out std_logic_vector(7 downto 0);
-- hex1 : out std_logic_vector(7 downto 0);
-- hex2 : out std_logic_vector(7 downto 0);
-- hex3 : out std_logic_vector(7 downto 0);
-- hex4 : out std_logic_vector(7 downto 0);
-- hex5 : out std_logic_vector(7 downto 0);

 vga_r     : out std_logic_vector(7 downto 0);
 vga_g     : out std_logic_vector(7 downto 0);
 vga_b     : out std_logic_vector(7 downto 0);
 vga_hs    : out std_logic;
 vga_vs    : out std_logic;
 
-- gsensor_cs_n : out   std_logic;
-- gsensor_int  : in    std_logic_vector(2 downto 0); 
-- gsensor_sdi  : inout std_logic;
-- gsensor_sdo  : inout std_logic;
-- gsensor_sclk : out   std_logic;

 arduino_io      : inout std_logic_vector(15 downto 0); 
-- arduino_reset_n : inout std_logic;
 
 gpio          : inout std_logic_vector(35 downto 0)

);
end c64_de10_lite;

architecture struct of c64_de10_lite is

	alias pwm_audio_out_l : std_logic is arduino_io(14);
	alias pwm_audio_out_r : std_logic is arduino_io(15);

	--alias tv15Khz_mode : std_logic is gpio_1_in(0);
	signal tv15Khz_mode   : std_logic;
	signal ntsc_init_mode : std_logic;
	
--	alias ps2_dat : std_logic is gpio_1(32);
--	alias ps2_clk : std_logic is gpio_1(33);
	
	signal c64_ram_addr   : std_logic_vector(15 downto 0);
	signal c64_ram_do     : std_logic_vector( 7 downto 0);
	signal c64_ram_di     : std_logic_vector( 7 downto 0);
	signal c64_ram_ce_n   : std_logic;
	signal c64_ram_we_n   : std_logic;

	signal ram_addr   : std_logic_vector(15 downto 0);
	signal ram_do     : std_logic_vector( 7 downto 0);
	signal ram_di     : std_logic_vector( 7 downto 0);
	signal ram_ce_n   : std_logic;
	signal ram_we_n   : std_logic;
	
--	alias sram_addr_l : std_logic is gpio(1);
--	alias sram_addr_m : std_logic_vector is gpio(20 downto 3);
--	
--	alias sram_ce_n : std_logic is gpio(21);
--	alias sram_we_n : std_logic is gpio(22);
--	alias sram_oe_n : std_logic is gpio(23);
--	alias sram_dq   : std_logic_vector is gpio(31 downto 24);
--

-- RJ comment next 6 lines
	alias ext_iec_atn_i  : std_logic is gpio(32);
	alias ext_iec_clk_o  : std_logic is gpio(33);
	alias ext_iec_data_o : std_logic is gpio(34);
	alias ext_iec_atn_o  : std_logic is gpio(35);
	alias ext_iec_data_i : std_logic is gpio(2);
	alias ext_iec_clk_i  : std_logic is gpio(0);
	
	--RJ make exterior
--	alias c64_iec_atn_i  : std_logic is gpio(32);
--	alias c64_iec_clk_o  : std_logic is gpio(33);
--	alias c64_iec_data_o : std_logic is gpio(34);
--	alias c64_iec_atn_o  : std_logic is gpio(35);
--	alias c64_iec_data_i : std_logic is gpio(2);
--	alias c64_iec_clk_i  : std_logic is gpio(0);

-- RJ comment next 6 lines	
	signal c64_iec_atn_i  : std_logic;
	signal c64_iec_clk_o  : std_logic;
	signal c64_iec_data_o : std_logic;
	signal c64_iec_atn_o  : std_logic;
	signal c64_iec_data_i : std_logic;
	signal c64_iec_clk_i  : std_logic;

	signal c1541_iec_atn_i  : std_logic;
	signal c1541_iec_clk_o  : std_logic;
	signal c1541_iec_data_o : std_logic;
	signal c1541_iec_atn_o  : std_logic;
	signal c1541_iec_data_i : std_logic;
	signal c1541_iec_clk_i  : std_logic;
	
	signal c1530_motor  : std_logic;
	signal c1530_write  : std_logic;
	signal c1530_sense  : std_logic;
	signal c1530_do     : std_logic;
	
	signal idle      : std_logic;
	signal pa2_out   : std_logic;
	
	signal clk32      : std_logic;
	signal clk18      : std_logic;
	signal pll_locked : std_logic;
	
	signal clk32_div : std_logic_vector(7 downto 0) := "00000000";

	signal clk16 : std_logic;
	signal clk08 : std_logic;
	signal clk01 : std_logic;
	signal r : unsigned(7 downto 0);
	signal g : unsigned(7 downto 0);
	signal b : unsigned(7 downto 0);
	signal hsync : std_logic;
	signal vsync : std_logic;
	signal csync : std_logic;
	signal blank : std_logic;

	signal audio_data_l : std_logic_vector(17 downto 0);
	signal audio_data_r : std_logic_vector(17 downto 0);
	signal pwm_accumulator_l : std_logic_vector(8 downto 0);
	signal pwm_accumulator_r : std_logic_vector(8 downto 0);

	signal dbg_track_dbl    : std_logic_vector(6 downto 0);
	signal dbg_sd_busy      : std_logic;
	signal dbg_sd_state     : std_logic_vector(7 downto 0);
	signal dbg_read_sector  : std_logic_vector(4 downto 0); 
	signal disk_num         : std_logic_vector(7 downto 0);
	signal dbg_mtr          : std_logic;
	signal dbg_act          : std_logic;
	signal dbg_num          : std_logic_vector( 2 downto 0);
	signal dbg_tape_addr    : std_logic_vector(15 downto 0);
	
	signal hex_sector_lsb   : std_logic_vector(7 downto 0);
	signal hex_sector_msb   : std_logic_vector(7 downto 0);
	
	signal reset_counter    : std_logic_vector(23 downto 0);
	signal erase_ram        : std_logic;
	signal reset            : std_logic := '0';
	signal reset_n          : std_logic;
	
	-- USB keyboard IF
	signal usb_start : std_logic := '0';
	signal usb_report : usb_report_t;
	signal new_usb_report : std_logic := '0';

	-- ps/2 keyboard emulation from USB IF
	-- (used for ctrl module input - single key at a time only)
	signal kbd_int : std_logic;
	signal kbd_scancode : std_logic_vector(7 downto 0);
	
	-- for sgt5000 audio
	signal sample_data  : std_logic_vector(31 downto 0);
	
	-- spi arbiter
	signal sd_spi_available   : std_logic;
	signal sd_spi_cs_n        : std_logic;
	signal sd_spi_mosi        : std_logic;
	signal sd_spi_miso        : std_logic;
	signal sd_spi_sclk        : std_logic;
	
	signal usb_spi_available  : std_logic;
	signal usb_spi_cs_n       : std_logic;
	signal usb_spi_mosi       : std_logic;
	signal usb_spi_miso       : std_logic;
	signal usb_spi_sclk       : std_logic;	

	-- c64 config
	signal st_c64gs            : std_logic;	
	signal st_audio_filter_off : std_logic;	
	signal st_sid_mode         : std_logic_vector(2 downto 0);	
	signal st_cia_mode         : std_logic;	
	
	-- ctrl module
	signal host_reset_n         : std_logic;
	signal host_divert_keyboard : std_logic;
	signal dipswitches          : std_logic_vector(15 downto 0);
	
	signal tap_control       : std_logic_vector( 7 downto 0);
	signal tap_counter_up    : std_logic_vector(31 downto 0);
	signal tap_counter_down  : std_logic_vector(31 downto 0);
	signal tap_data          : std_logic_vector(31 downto 0);
	signal tap_wrreq         : std_logic;
	signal tap_fifo_wrfull   : std_logic;	
	signal tap_fifo_error    : std_logic;
		
	signal d64_start_sector : std_logic_vector(8 downto 0);
	signal d64_save_track   : std_logic;
	signal d64_control      : std_logic_vector(7 downto 0);
	signal d64_data_out     : std_logic_vector(31 downto 0);
	signal d64_wrreq        : std_logic;
	signal d64_wrack        : std_logic;
	signal d64_data_in      : std_logic_vector(31 downto 0);
	signal d64_rdreq        : std_logic;
	signal d64_rdack        : std_logic;

	-- osd
	signal osd_window : std_logic;
	signal osd_pixel  : std_logic;
	signal osd_r      : std_logic_vector(7 downto 0);	
	signal osd_g      : std_logic_vector(7 downto 0);	
	signal osd_b      : std_logic_vector(7 downto 0);

	-- hot key (F9)
	signal play_stop_toggle  : std_logic;

	-- hex display
--	signal hex_t0,hex_t1,hex_t2,hex_t3,hex_t4,hex_t5 : std_logic_vector(7 downto 0);
--	signal hex_d0,hex_d1,hex_d2,hex_d3,hex_d4,hex_d5 : std_logic_vector(7 downto 0);
--	signal tap_counter : std_logic_vector(31 downto 0);
	
component sdram is port 
(
   -- interface to the MT48LC16M16 chip
   sd_addr    : out   std_logic_vector(12 downto 0);
   sd_data    : inout std_logic_vector(15 downto 0);
   sd_cs      : out   std_logic;
   sd_ba      : out   std_logic_vector(1 downto 0);
   sd_we      : out   std_logic;
   sd_ras     : out   std_logic;
   sd_cas     : out   std_logic;

   -- system interface
   clk        : in    std_logic;
   init       : in    std_logic;

   -- cpu/chipset interface
   addr       : in    std_logic_vector(24 downto 0);
   din        : in    std_logic_vector( 7 downto 0);
   dout       : out   std_logic_vector( 7 downto 0);
   refresh    : in    std_logic;
   we         : in    std_logic;
   ce         : in    std_logic
);
end component;

	
begin

--arduino_io(4 downto 0) <= (others => 'Z');
--arduino_io(9 downto 6) <= (others => 'Z');
arduino_io(5) <= 'Z';
arduino_io(9 downto 7) <= (others => 'Z');
--arduino_io(15 downto 14) <= (others => 'Z');

--RJ 
tv15Khz_mode <= sw(0);
-- 
ntsc_init_mode <= sw(1);
--tv15Khz_mode <= '0';
--ntsc_init_mode <= '1'; --sw(1);
	
clk_32_18 : entity work.max_10_pll50_to_32_and_18
port map(
	inclk0 => max10_clk1_50,
	c0 => clk32,
	c1 => clk18,
	locked => pll_locked
);

process(clk32)
begin
	if rising_edge(clk32) then
		if clk32_div = "11111111" then
			clk32_div <= "00000000";
		else
			clk32_div  <= clk32_div + '1';			
		end if;
	end if;
end process;

clk16 <= clk32_div(0);
clk08 <= clk32_div(1);
clk01 <= clk32_div(4);

process(clk32, key(0), host_reset_n, pll_locked)
begin
	if key(0) = '0' or pll_locked = '0' or host_reset_n = '0'then
		reset_n <= '0';
		usb_start <= '0';
		erase_ram <= '1';
		reset_counter <= (others => '0');
	else
		if rising_edge(clk32) then
			if reset_counter > X"0000F0" and reset_counter < X"0000FF" then
				usb_start <= '1';			
			end if;
							
			if reset_counter < X"FFFFFF" then
				reset_counter <= reset_counter + '1';
			else
				reset_n <= '1';
				erase_ram <= '0';
			end if;
		end if;
	end if;
end process;

reset <= not reset_n;

st_c64gs            <= dipswitches(0);
st_sid_mode         <= dipswitches(3 downto 1);
st_audio_filter_off <= dipswitches(4);
st_cia_mode         <= dipswitches(5);

fpga64 : entity work.fpga64_sid_iec
	port map(
		clk32 => clk32,
		reset_n => reset_n,
		c64gs => st_c64gs,

		kbd_clk => '1', --ps2_clk,
		kbd_dat => '1', --ps2_dat,
		
		usb_report_clk => clk08,
		usb_report     => usb_report,
		new_usb_report => new_usb_report and not host_divert_keyboard,
		
		ramAddr => c64_ram_addr,  --c64_addr_int,
		ramDataOut => c64_ram_do, --c64_data_out_int,
		ramDataIn => c64_ram_di,  --c64_data_in_int,
		ram_ce_n  => c64_ram_ce_n,
		ram_we_n  => c64_ram_we_n,
		tv15Khz_mode => tv15Khz_mode,
		ntscInitMode => ntsc_init_mode,
		hsync => hsync,
		vsync => vsync,
		r => r,
		g => g,
		b => b,
		game => '1',--game,
		exrom => '1', --exrom,
		UMAXromH => open,--UMAXromH,
		CPU_hasbus => open, --CPU_hasbus,		
		ioE_rom => '1', --ioE_rom,
		ioF_rom => '1', --ioF_rom,
		max_ram => '0', --max_ram,
		irq_n => '1',
		nmi_n => '1', --not nmi,
		nmi_ack => open, --nmi_ack,
		freeze_key => open, --freeze_key,
		dma_n => '1',
		romL => open,--romL,
		romH => open,--romH,
		IOE => open, --IOE,									
		IOF => open, --IOF,
		ba => open,
		joyA => (others => '0'),   --unsigned(joyA_c64),
		joyB => (others => '0'),   --unsigned(joyB_c64),
		potA_x => (others => '0'), --potA_x,
		potA_y => (others => '0'), --potA_y,
		potB_x => (others => '0'), --potB_x,
		potB_y => (others => '0'), --potB_y,
		serioclk => open,
		ces => open, --ces,
		SIDclk => open,
		still => open,
		idle => idle,
		audio_data_l => audio_data_l,
		audio_data_r => audio_data_r,
		extfilter_en => not st_audio_filter_off,
		sid_mode => st_sid_mode,
		iec_data_o => c64_iec_data_o,
		iec_atn_o  => c64_iec_atn_o,
		iec_clk_o  => c64_iec_clk_o,
		iec_data_i => c64_iec_data_i,
		iec_clk_i  => c64_iec_clk_i,
--		iec_atn_i  => not c64_iec_atn_i,
		pa2_in => pa2_out,        --pa2_in,
		pa2_out => pa2_out,
		pb_in => (others => '1'), --pb_in,
		pb_out => open,           --pb_out,
		flag2_n => '1',           --flag2_n,
		todclk => '1',            --todclk,
		cia_mode => st_cia_mode,
		disk_num => disk_num,  -- Not used since managed at ctrl module level

		cass_motor => c1530_motor,
		cass_write => c1530_write,
		cass_read  => c1530_do,
		cass_sense => c1530_sense,
		
		c64rom_addr => (others => '0'), --c64rom_addr,
		c64rom_data => (others => '0'), --ioctl_data,
		c64rom_wr => '0',               --c64rom_wr,
--		cart_detach_key => cart_detach_key,
		tap_playstop_key => open,       --tap_playstop_key,
		reset_key => open               --reset_key
	);


-- RJ ORG iec wiring (external IEC commented)
--c64_iec_atn_i  <= not ((not c64_iec_atn_o)  and (not c1541_iec_atn_o) ); --or (ext_iec_atn_i  );
--c64_iec_data_i <= not ((not c64_iec_data_o) and (not c1541_iec_data_o)); --or (ext_iec_data_i );
--c64_iec_clk_i  <= not ((not c64_iec_clk_o)  and (not c1541_iec_clk_o) ); --or ext_iec_clk_i  );
	
-- iec wiring (external IEC commented) RJ Changed logic
c64_iec_atn_i  <= not ((not c64_iec_atn_o)  and (not c1541_iec_atn_o ) and (ext_iec_atn_i  ));
c64_iec_data_i <= not ((not c64_iec_data_o) and (not c1541_iec_data_o) and (ext_iec_data_i ));
c64_iec_clk_i  <= not ((not c64_iec_clk_o)  and (not c1541_iec_clk_o ) and (ext_iec_clk_i  ));
	
c1541_iec_atn_i  <= c64_iec_atn_i;
c1541_iec_data_i <= c64_iec_data_i;
c1541_iec_clk_i  <= c64_iec_clk_i;

-- external IEC commented
ext_iec_atn_o  <= c64_iec_atn_o   or c1541_iec_atn_o;
ext_iec_data_o <= c64_iec_data_o  or c1541_iec_data_o;
ext_iec_clk_o  <= c64_iec_clk_o   or c1541_iec_clk_o;
	
-- c1541 sd emulator
c1541_sd : entity work.c1541_sd
port map
(
	clk32 => clk32,
--	clk_spi_ctrlr => clk16,
	reset => not reset_n,
	
	disk_num => ("00" & disk_num), -- not used
	disk_readonly => dipswitches(8),
	
	iec_atn_i  => c1541_iec_atn_i,
	iec_data_i => c1541_iec_data_i,
	iec_clk_i  => c1541_iec_clk_i,
	
	iec_atn_o  => c1541_iec_atn_o,
	iec_data_o => c1541_iec_data_o,
	iec_clk_o  => c1541_iec_clk_o,
	
--	sd_miso  => sd_spi_miso, 
--	sd_cs_n  => sd_spi_cs_n, 
--	sd_mosi  => sd_spi_mosi,
--	sd_sclk  => sd_spi_sclk,
--	bus_available => sd_spi_available,

	d64_start_sector => d64_start_sector, 
	track_loading    => d64_control(0),
	save_track       => d64_save_track,
	d64_data_out     => d64_data_out,
	d64_wrreq        => d64_wrreq,
	d64_wrack        => d64_wrack,
	d64_data_in      => d64_data_in,
	d64_rdreq        => d64_rdreq,
	d64_rdack        => d64_rdack,

	dbg_track_num_dbl => dbg_track_dbl,
	dbg_sd_busy       => dbg_sd_busy,
	dbg_sd_state      => dbg_sd_state,
	dbg_read_sector   => dbg_read_sector,
	dbg_mtr           => dbg_mtr,
	dbg_act           => dbg_act
		
);

-- c1530 emulator
c1530 : entity work.c1530
port map
(
	clk32 => clk32,
	restart_tape => tap_control(0),

	wav_mode    => '0',  -- for .wav file /!\ not tested anymore
	tap_version => tap_control(1),

	host_tap_in     => tap_data,
	host_tap_wrreq  => tap_wrreq,
	tap_fifo_wrfull => tap_fifo_wrfull,
	tap_fifo_error  => tap_fifo_error,
	
	osd_play_stop_toggle => play_stop_toggle, -- PLAY/STOP toggle button from OSD

	cass_sense => c1530_sense,  -- 0 = PLAY/REW/FF/REC button is pressed
	cass_read  => c1530_do,     -- tape read signal
	cass_write => '1',          -- signal to write on tape (not used)
	cass_motor => c1530_motor,  -- 0 = tape motor is powered
	
	ear_input  => '1'   -- tape input from EAR port

);

--sram_addr_m <= "000"&c64_addr(15 downto 1);
--sram_addr_l <= c64_addr(0);
--sram_ce_n <= c64_ram_ce_n;
--sram_we_n <= c64_ram_we_n;
--sram_oe_n <= not c64_ram_we_n;
--c64_ram_di <= sram_dq;
--sram_dq <= c64_ram_do when c64_ram_we_n = '0' else (others => 'Z');

ram_addr <= c64_ram_addr when erase_ram = '0' else reset_counter(20 downto 5);
ram_di   <= c64_ram_do   when erase_ram = '0' else x"00";
ram_we_n <= c64_ram_we_n when erase_ram = '0' else '0';
ram_ce_n <= c64_ram_ce_n when erase_ram = '0' else reset_counter(4);
c64_ram_di <= ram_do;

dram_clk  <= not clk32;
dram_cke  <= '1';
dram_ldqm <= '0';
dram_udqm <= '0';

sdr: sdram
port map(
	sd_addr => dram_addr,
	sd_data => dram_dq,
	sd_ba =>   dram_ba,
	sd_cs =>   dram_cs_n,
	sd_we =>   dram_we_n,
	sd_ras =>  dram_ras_n,
	sd_cas =>  dram_cas_n,

	clk  => clk32,
	addr => '0'&x"00"&ram_addr,
	din  => ram_di,
	dout => ram_do,
	init => not pll_locked,
	we   => not ram_we_n,
	refresh => idle,
	ce   => not ram_ce_n
);

vga_r <= std_logic_vector(osd_r(7 downto 0));-- when blank = '0' else (others => '0');
vga_g <= std_logic_vector(osd_g(7 downto 0));-- when blank = '0' else (others => '0');
vga_b <= std_logic_vector(osd_b(7 downto 0));-- when blank = '0' else (others => '0');

comp_sync : entity work.composite_sync
port map(
	clk32 => clk32,
	hsync => not hsync,
	vsync => not vsync,
	csync => csync,
	blank => blank
);

-- synchro composite/ synchro horizontale
vga_hs <= csync when tv15Khz_mode = '1' else hsync;
-- commutation rapide / synchro verticale
vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

-- pwm  sound	
process(clk18)
	variable count_l  : std_logic_vector(4 downto 0) := (others => '0');
	variable count_r  : std_logic_vector(4 downto 0) := (others => '0');
begin
	if rising_edge(clk32) then
		if count_l = "01000" then
			count_l := (others => '0');
			pwm_accumulator_l  <=  ('0' & pwm_accumulator_l(7 downto 0)) + 
										("00"&audio_data_l(17 downto 12));
		else
			count_l := count_l + '1';
		end if;
		if count_r = "01000" then
			count_r := (others => '0');
			pwm_accumulator_r  <=  ('0' & pwm_accumulator_r(7 downto 0)) + 
										("00"&audio_data_r(17 downto 12));
		else
			count_r := count_r + '1';
		end if;
	end if;
end process;
	
pwm_audio_out_l <= pwm_accumulator_l(8);
pwm_audio_out_r <= pwm_accumulator_r(8);

-- audio for sgtl5000 
--sample_data <= audio_data_l(17 downto 2) & audio_data_r(17 downto 2);
--
---- sgtl5000 (teensy audio shield on top of usb host shield)
--e_sgtl5000 : entity work.sgtl5000_dac
--port map(
-- clock_18   => clk18,
-- reset      => reset,
-- i2c_clock  => clk01,  
--
-- sample_data  => sample_data,
-- 
-- i2c_sda   => arduino_io(0), -- i2c_sda, 
-- i2c_scl   => arduino_io(1), -- i2c_scl, 
--
-- tx_data   => arduino_io(2), -- sgtl5000 tx
-- mclk      => arduino_io(4), -- sgtl5000 mclk 
-- 
-- lrclk     => arduino_io(3), -- sgtl5000 lrclk
-- bclk      => arduino_io(6), -- sgtl5000 bclk   
-- 
-- -- debug
---- hex0_di   => open, -- hex0_di,
---- hex1_di   => open, -- hex1_di,
---- hex2_di   => open, -- hex2_di,
---- hex3_di   => open, -- hex3_di,
-- 
-- sw => (others => '0') --sw(7 downto 0)
--);

 -- usb host for max3421e arduino modified shield
usb_host : entity work.usb_host_max3421e
port map(
 clk     => clk08,
 reset   => reset,
 start   => usb_start, -- start usb enumeration
 
 usb_report => usb_report,
 new_usb_report => new_usb_report,
 
 spi_cs_n  => usb_spi_cs_n, 
 spi_clk   => usb_spi_sclk,
 spi_mosi  => usb_spi_mosi,
 spi_miso  => usb_spi_miso,
 
 bus_available => usb_spi_available
);


usb_to_ps2 : entity work.usb_to_ps2_keyboard
port map(

	clk => clk08,
	usb_report     => usb_report,
	new_usb_report => new_usb_report,
	
	kbd_int => kbd_int,
	kbd_scancode => kbd_scancode,
	
	play_stop_toggle => play_stop_toggle

);

arduino_io(10) <= usb_spi_cs_n when usb_spi_available = '1' else '1';
arduino_io(05) <= sd_spi_cs_n  when sd_spi_available  = '1' else '1';

arduino_io(13) <= usb_spi_sclk when usb_spi_available  = '1' else sd_spi_sclk;
arduino_io(11) <= usb_spi_mosi when usb_spi_available  = '1' else sd_spi_mosi;

usb_spi_miso <= arduino_io(12) when usb_spi_available = '1' else '1';
sd_spi_miso  <= arduino_io(12) when sd_spi_available  = '1' else '1';

-- sd_spi_cs_n  : arduino_io(05) 
-- usb_spi_cs_n : arduino_io(10)
-- mosi         : arduino_io(11),
-- miso         : arduino_io(12)
-- sclk         : arduino_io(13)

-- sd_card / usb keyboard spi arbiter
spi_arbiter :  process(clk16)
begin
	if rising_edge(clk16) then
	
		if (usb_spi_available = '0') and (sd_spi_available = '0') then
			if sd_spi_cs_n = '0' then
				sd_spi_available <= '1';
			elsif usb_spi_cs_n = '0' then
				usb_spi_available <= '1';
		   else
				null;
			end if;
		else
			if (sd_spi_available = '1') and  (sd_spi_cs_n = '1') then
				sd_spi_available <= '0';
			end if;
			if (usb_spi_available = '1') and  (usb_spi_cs_n = '1') then
				usb_spi_available <= '0';
			end if;		
		end if;
		
	end if;	
end process;	 
 
-- Control module for tap/wav loading
-- just read wav/tap file content and send it to
-- 32bits I/F host_tap_data and host_tap_wrreq
-- as long as tap_fifo_wrfull = 0, wait when tap_fifo_wrfull = 1

-- SPI clk around 16MHz for sd access 
-- (must be high enough for wav mode not starving c1530 fifo)

control_module : entity work.CtrlModule
generic map
(
	sysclk_frequency => 500
)
port map
(
	clk       => clk32,
	reset_n   => key(1),
	vga_hsync => hsync,
	vga_vsync => vsync,
	
	osd_window => osd_window,
	osd_pixel  => osd_pixel,
	
	ps2k_clk_in => '1', -- (not used : use kbd_int/kbd_scancode instead)
	ps2k_dat_in => '1', -- (not used : use kbd_int/kbd_scancode instead)
	
	kbd_int => kbd_int,
	kbd_scancode => kbd_scancode,
	
	spi_available => sd_spi_available,
	spi_miso      => sd_spi_miso,
	spi_mosi      => sd_spi_mosi,
	spi_clk       => sd_spi_sclk,
	spi_cs        => sd_spi_cs_n,

	dipswitches   => dipswitches,
	
	joy_pins => "000000",		

	-- Host control signals
	host_reset_n         => host_reset_n,
	host_divert_sdcard   => open,
	host_divert_keyboard => host_divert_keyboard,
		
	-- TAP upload signals
	tap_control => tap_control,
	tap_data    => tap_data,
	tap_wrreq   => tap_wrreq,
	tap_wrack   => not tap_fifo_wrfull,
	tap_counter_up   => tap_counter_up,
	tap_counter_down => tap_counter_down,
	
	-- Track upload/save signals
	d64_control      => d64_control,
	d64_start_sector => d64_start_sector, 
	d64_save_track   => d64_save_track,
	d64_data_out     => d64_data_out,
	d64_wrreq        => d64_wrreq,
	d64_wrack        => d64_wrack,
	d64_data_in      => d64_data_in,
	d64_rdreq        => d64_rdreq,
	d64_rdack        => d64_rdack

);

osd_overlay : entity work.OSD_Overlay
port map(
	clk           => clk32,
	red_in        => std_logic_vector(r),
	green_in      => std_logic_vector(g),
	blue_in       => std_logic_vector(b),
	window_in     => '0',
	hsync_in      => hsync,
	osd_window_in => osd_window,
	osd_pixel_in  => osd_pixel,
	red_out       => osd_r,
	green_out     => osd_g,
	blue_out      => osd_b,
	window_out    => open,
	scanline_ena  => '0'
);


-- tap_counter <= tap_counter_up when dipswitches(6)='0' else tap_counter_down;		



end struct;
