-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
-- Principle : (after card init)
--		* read track_size data (26*256 bytes) from sd card to ram buffer when 
-- 	disk_num or track_num change
--    * write track_size data back from ram buffer to sd card when save_track
--    is pulsed to '1'
--
--	   Data read from sd_card always start on 512 bytes boundaries.
--		When actual D64 track starts on 512 bytes boundary sector_offset is set
--    to 0.
--		When actual D64 track starts on 256 bytes boundary sector_offset is set
--    to 1.
--		External ram buffer 'user' should mind sector_offset to retrieve correct
--    data offset.
--
-- 	One should be advised that extra bytes may be read and write out of disk
--    boundary when using last track. With a single sd card user this should 
-- 	lead to no problem since written data always comes from the exact same
--		read place (extra written data will replaced same value on disk).
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity track_loader is
port (

	-- host interface ---------------------------------------------------------
	d64_start_sector : out std_logic_vector(8 downto 0); -- 512 bytes sector for sd card
	track_loading    : in std_logic;
	d64_data_out     : in std_logic_vector(31 downto 0);
	d64_wrreq        : in std_logic;  -- set to 1 by host when data ready
	d64_wrack        : out std_logic; -- set to 1 by ctrl to acknowlegde data
	d64_data_in      : out std_logic_vector(31 downto 0);
	d64_rdreq        : in std_logic;  -- set to 1 by host when data ready
	d64_rdack        : out std_logic; -- set to 1 by ctrl to acknowlegde data
	 
	-- Track buffer Interface -------------------------------------------------
	ram_addr       : out std_logic_vector(12 downto 0);
	ram_di         : out std_logic_vector(7 downto 0);
	ram_do         : in  std_logic_vector(7 downto 0);
	ram_we         : out std_logic;
	track_num      : in  std_logic_vector(5 downto 0);  -- Track number (0/1-40)
	busy           : buffer std_logic;
	sector_offset  : out std_logic;  -- 0 : sector 0 is at ram adr 0, 1 : sector 0 is at ram adr 256
	-- System Interface -------------------------------------------------------
	clk            : in  std_logic;  -- System clock	 
	reset          : in  std_logic;
	-- Debug ------------------------------------------------------------------
	dbg_state      : out std_logic_vector(7 downto 0)  
);
end track_loader;

architecture rtl of track_loader is
  
signal ram_addr_in       : std_logic_vector(12 downto 0) := (others => '0');
  
-- C64 - 1541 start_sector in D64 format per track number [0..40]
type start_sector_array_type is array(0 to 40) of integer range 0 to 1023;
signal start_sector_array : start_sector_array_type := 
	(  0,  0, 21, 42, 63, 84,105,126,147,168,189,210,231,252,273,294,315,336,357,376,395,
	414,433,452,471,490,508,526,544,562,580,598,615,632,649,666,683,700,717,734,751);
	
signal start_sector_addr : std_logic_vector(9 downto 0); -- addresse of sector within full disk

signal state : std_logic_vector(3 downto 0) := x"0";
		
begin
-----------------------------------------------------------------------------
start_sector_addr <= std_logic_vector(to_unsigned(start_sector_array(to_integer(unsigned(track_num))),10));
d64_start_sector <= start_sector_addr(9 downto 1);
sector_offset <= start_sector_addr(0);				

ram_addr <= ram_addr_in;
	
track_loader : process(clk, track_loading)
begin
	if rising_edge(clk) then
	
		if track_loading <= '0' then		
			d64_wrack <= '1'; -- don't stop host when nothing is awaiting
			d64_rdack <= '1'; -- don't stop host when nothing is awaiting
			state <= x"0";
			busy <= '0';
			ram_addr_in <= (others => '0');
		else	
	
			busy <= '1';
			
			case state is
			when X"0" =>			
				d64_wrack <= '0';				
				d64_rdack <= '0';				
				if (d64_wrreq = '1') or (d64_rdreq = '1') then
					ram_di <= d64_data_out(31 downto 24);
					ram_we <= d64_wrreq; -- '1';
					state <= state + '1';
				end if;

			when X"1" =>
            ram_addr_in <= ram_addr_in + '1';
				ram_di <= d64_data_out(23 downto 16);
				d64_data_in(31 downto 24) <= ram_do;
				ram_we <= d64_wrreq; -- '1';
				state <= state + '1';
			
			when X"2" =>
            ram_addr_in <= ram_addr_in + '1';
				ram_di <= d64_data_out(15 downto 8);
				d64_data_in(23 downto 16) <= ram_do;
				ram_we <= d64_wrreq; -- '1';
				state <= state + '1';

			when X"3" =>
            ram_addr_in <= ram_addr_in + '1';
				ram_di <= d64_data_out(7 downto 0);
				d64_data_in(15 downto 8) <= ram_do;
				ram_we <= d64_wrreq; -- '1';
				state <= state + '1';
	
			when X"4" =>
            ram_addr_in <= ram_addr_in + '1';
				d64_data_in(7 downto 0) <= ram_do;
				ram_we <= '0';
				d64_wrack <= '1';				
				d64_rdack <= '1';				
				state <= state + '1';
				
			when X"5" =>
				if ram_addr_in > '1'&x"600" then 
					state <= x"6";
				else
					state <= x"0";
				end if;
				
			when X"6" =>
				d64_wrack <= '1';				
				d64_rdack <= '1';				
				
			when others =>
					state <= x"0";				
			end case;
			
		end if;
		
	end if;
end process;
	
end rtl;
