-- -----------------------------------------------------------------------
-- Usb to PS/2 keyboard by Dar (darfpga@aol.fr) 04-Mai-2019
-- http://darfpga.blogspot.fr
-- also darfpga on sourceforge
--
-- Manage only one key at a time
-- Manage only some of those keys required for ctrl_module
-- -----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.usb_report_pkg.all;

-- Translation   PS/2  USB
--
-- PS/2 code + 0x80 for extended code

--KEY_F1         0x05  0x3A
--KEY_F2         0x06  0x3B
--KEY_F3         0x04  0x3C
--KEY_F4         0x0C  0x3D
--KEY_F5         0x03  0x3E
--KEY_F6         0x0B  0x3F
--KEY_F7         0x83  0x40
--KEY_F8         0x0A  0x41
--KEY_F9         0x01  0x42
--KEY_F10        0x09  0x43
--KEY_F11        0x78  0x44
--KEY_F12        0x07  0x45
--
--KEY_CAPSLOCK   0x58  0x39
--KEY_NUMLOCK    0x77  0x53
--KEY_SCROLLLOCK 0x7e  0x47
--KEY_LEFTARROW  0xeb  0x50
--KEY_RIGHTARROW 0xf4  0x4F
--KEY_UPARROW    0xf5  0x52
--KEY_DOWNARROW  0xf2  0x51
--KEY_ENTER      0x5a  0x28
--KEY_PAGEUP     0xfd  0x4B
--KEY_PAGEDOWN   0xfa  0x4E
--KEY_SPACE      0x29  0x2C
--KEY_ESC        0x76  0x29
--
--KEY_A          0x1c  0x14 -french
--KEY_D          0x23  0x07
--KEY_P          0x4d  0x13
--KEY_S          0x1b  0x16
--KEY_T          0x2c  0x17
--KEY_W          0x1d  0x1D
--
--KEY_1          0x16  0x1E
--KEY_2          0x1E  0x1F
--
--KEY_LSHIFT     0x12
--KEY_RSHIFT     0x59
--KEY_LCTRL      0x14
--KEY_RCTRL      0x94
--KEY_ALT	     0x11
--KEY_ALTGR      0x91

entity usb_to_ps2_keyboard is
port (
	clk : in std_logic; -- max3421e_clk;		
	usb_report     : in usb_report_t;
	new_usb_report : std_logic; -- one clock cycle duration

	kbd_int : out std_logic;
	kbd_scancode : out std_logic_vector(7 downto 0);
	
	play_stop_toggle : out std_logic
);
end usb_to_ps2_keyboard;

architecture rtl of usb_to_ps2_keyboard is

	constant KEY_LEFTARROW : std_logic_vector(7 downto 0) := x"50";
	constant KEY_RIGHTARROW: std_logic_vector(7 downto 0) := x"4F";
	constant KEY_UPARROW   : std_logic_vector(7 downto 0) := x"52";
	constant KEY_DOWNARROW : std_logic_vector(7 downto 0) := x"51";
	constant KEY_ENTER     : std_logic_vector(7 downto 0) := x"28";
	constant KEY_PAGEUP    : std_logic_vector(7 downto 0) := x"4B";
	constant KEY_PAGEDOWN  : std_logic_vector(7 downto 0) := x"4E";
	constant KEY_SPACE     : std_logic_vector(7 downto 0) := x"2C";
	constant KEY_ESC       : std_logic_vector(7 downto 0) := x"29";

	signal send_up  : std_logic;
	signal send_key : std_logic;
	signal key_dwn  : std_logic_vector(7 downto 0);
	signal ps2_key  : std_logic_vector(7 downto 0);
	signal wait_cnt : std_logic_vector(11 downto 0);
	
	
	-- for usb keyboard
	signal usb_ctrll : std_logic;
	signal usb_shiftl : std_logic;
	signal usb_altl : std_logic;
	signal usb_shiftr : std_logic;
	signal usb_altr : std_logic;
	signal usb_shift : std_logic;
	
begin

scan_usb_buffer: process(clk)
	variable byte_cnt : integer range 0 to 10;
begin
			
	if rising_edge(clk) then

		kbd_int <= '0';

		if new_usb_report = '1' then
			-- usb keyboard report is 9 bytes
			-- first byte (#0) is max3421e status
			-- then 2 bytes are for modifiers keys
			-- then 6 bytes are normal keys list

			usb_ctrll  <= usb_report(1)(0);
			usb_shiftl <= usb_report(1)(1);
			usb_altl   <= usb_report(1)(2);
			usb_shiftr <= usb_report(1)(5);
			usb_altr   <= usb_report(1)(6);

			usb_shift  <= usb_report(1)(1) or usb_report(1)(5);

			if usb_report(3) = X"01" then
			-- if byte #3 = 0x01 keyboard overflow (too many keys down)
			-- then keep previous keys pattern
				byte_cnt := 10;
			else -- no overflow, allow keys list scanning			
				byte_cnt := 3;

				play_stop_toggle <= '0';
			end if;
		end if; -- new_usb_report
		
		-- scan bytes #3 to #9 for normal keys
		if byte_cnt < 10 then
		
			if usb_report(byte_cnt) = x"42" then -- F9
				play_stop_toggle <= '1';
			end if;
		
			-- catch key to simulate ps2 keyboard scancode
			-- (only first key is taken into account)
			if	key_dwn = usb_report(3) then 
				-- no change		
			else			
				if usb_report(3) = X"00" then
					-- key newly up
					send_up <= '1';
				else					
					-- key newly down
						key_dwn <= usb_report(3);
						send_key <= '1';
				end if;				
			end if;
								
			byte_cnt := byte_cnt +1;
		end if; -- usb report key scan

		if byte_cnt = 10 then
		
			if send_up = '1' and send_key = '0' then			
				send_key <= '1';
				kbd_int <= '1';
				kbd_scancode <= X"F0";
				wait_cnt <= X"FFF"; -- do not send scancode too fast.
			
			end if;

			if send_up = '1' and send_key = '1' and wait_cnt = X"00" then
				send_key <= '0';
				send_up <= '0';
				kbd_int <= '1';
				kbd_scancode <= ps2_key;
				key_dwn <= X"00";
			end if; 
			
			if send_up = '0' and send_key = '1' and wait_cnt = X"00" then
				send_key <= '0';
				kbd_int <= '1';
				kbd_scancode <= ps2_key;				
			end if;
		
			wait_cnt <= wait_cnt - '1';
		
		end if;
			
	end if; -- clk
end process;

with key_dwn select
ps2_key <= x"eb" when KEY_LEFTARROW,
           x"f4" when KEY_RIGHTARROW,
           x"f5" when KEY_UPARROW,
           x"f2" when KEY_DOWNARROW,
           x"5a" when KEY_ENTER,
           x"fd" when KEY_PAGEUP,
           x"fa" when KEY_PAGEDOWN,
           x"29" when KEY_SPACE,
           x"76" when KEY_ESC,
           x"00" when others;			  

end architecture;
