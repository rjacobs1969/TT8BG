-- -----------------------------------------------------------------------
--
--                                 FPGA 64
--
--     A fully functional commodore 64 implementation in a single FPGA
--
-- -----------------------------------------------------------------------
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
-- -----------------------------------------------------------------------
-- 'Joystick emulation on keypad' additions by
-- Mark McDougall (msmcdoug@iinet.net.au)
-- -----------------------------------------------------------------------
-- USB modification by Dar   (DarFPGA@blogspot.fr)     08/05/2017
-- US Keyboard layout by RJa (elholandes44@gmail.com)  17/11/2020
-- -----------------------------------------------------------------------
--
-- VIC20/C64 Keyboard matrix
--
-- Hardware huh?
--	In original machine if a key is pressed a contact is made.
--	Bidirectional reading is possible on real hardware, which is difficult
--	to emulate. (set backwardsReadingEnabled to '1' if you want this enabled).
--	Then we have the joysticks, one of which is normally connected
--	to a OUTPUT pin.
--
-- Emulation:
--	All pins are high except when one is driven low and there is a
--	connection. This is consistent with joysticks that force a line
--	low too. CIA will put '1's when set to input to help this emulation.
--
-- -----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.usb_report_pkg.all;

entity fpga64_keyboard_usb_french is
	port (
		clk : in std_logic; -- max3421e_clk;
		
		usb_report     : in usb_report_t;
		new_usb_report : std_logic; -- one clock cycle duration

		joyA: in unsigned(4 downto 0);
		joyB: in unsigned(4 downto 0);

		pai: in unsigned(7 downto 0);
		pbi: in unsigned(7 downto 0);
		pao: out unsigned(7 downto 0);
		pbo: out unsigned(7 downto 0);
		
		videoKey : out std_logic;
		traceKey : out std_logic;
		trace2Key : out std_logic;
		disk_num : out std_logic_vector(7 downto 0);
		dbg_num : out std_logic_vector(2 downto 0);
		
		rawUsbKey: out std_logic_vector(15 downto 0);
		nmi: out std_logic; 
		reset: out std_logic;
		-- Config
		-- backwardsReadingEnabled = 1 allows reversal of PIA registers to still work.
		-- not needed for kernel/normal operation only for some specific programs.
		-- set to 0 to save some hardware.
		backwardsReadingEnabled : in std_logic
	);
end fpga64_keyboard_usb_french;

architecture rtl of fpga64_keyboard_usb_french is	
	signal extendedFlag: std_logic := '0';
	signal releaseFlag: std_logic := '0';

	signal key_del: std_logic := '0';
	signal key_return: std_logic := '0';
	signal key_left: std_logic := '0';
	signal key_right: std_logic := '0';
	signal key_f7: std_logic := '0';
	signal key_f1: std_logic := '0';
	signal key_f3: std_logic := '0';
	signal key_f5: std_logic := '0';
	signal key_up: std_logic := '0';
	signal key_down: std_logic := '0';

	signal key_3: std_logic := '0';
	signal key_W: std_logic := '0';
	signal key_A: std_logic := '0';
	signal key_4: std_logic := '0';
	signal key_Z: std_logic := '0';
	signal key_S: std_logic := '0';
	signal key_E: std_logic := '0';
	signal key_shiftl: std_logic := '0';

	signal key_5: std_logic := '0';
	signal key_R: std_logic := '0';
	signal key_D: std_logic := '0';
	signal key_6: std_logic := '0';
	signal key_C: std_logic := '0';
	signal key_F: std_logic := '0';
	signal key_T: std_logic := '0';
	signal key_X: std_logic := '0';
	
	signal key_7: std_logic := '0';
	signal key_Y: std_logic := '0';
	signal key_G: std_logic := '0';
	signal key_8: std_logic := '0';
	signal key_B: std_logic := '0';
	signal key_H: std_logic := '0';
	signal key_U: std_logic := '0';
	signal key_V: std_logic := '0';

	signal key_9: std_logic := '0';
	signal key_I: std_logic := '0';
	signal key_J: std_logic := '0';
	signal key_0: std_logic := '0';
	signal key_M: std_logic := '0';
	signal key_K: std_logic := '0';
	signal key_O: std_logic := '0';
	signal key_N: std_logic := '0';

	signal key_plus: std_logic := '0';
	signal key_P: std_logic := '0';
	signal key_L: std_logic := '0';
	signal key_minus: std_logic := '0';
	signal key_dot: std_logic := '0';
	signal key_colon: std_logic := '0';
	signal key_at: std_logic := '0';
	signal key_comma: std_logic := '0';

	signal key_pound: std_logic := '0';
	signal key_star: std_logic := '0';
	signal key_semicolon: std_logic := '0';
	signal key_home: std_logic := '0';
	signal key_shiftr: std_logic := '0';
	signal key_equal: std_logic := '0';
	signal key_arrowup: std_logic := '0';
	signal key_slash: std_logic := '0';

	signal key_1: std_logic := '0';
	signal key_arrowleft: std_logic := '0';
	signal key_ctrl: std_logic := '0';
	signal key_2: std_logic := '0';
	signal key_space: std_logic := '0';
	signal key_commodore: std_logic := '0';
	signal key_Q: std_logic := '0';
	signal key_runstop: std_logic := '0';

	-- for joystick emulation on PS2
	signal joySelKey : std_logic;
	signal joyKeys : std_logic_vector(joyA'range);	-- active high
	signal joyA_s : unsigned(joyA'range);				-- active low
	signal joyB_s : unsigned(joyB'range);				-- active low
	signal joySel : std_logic_vector(1 downto 0) := "00";
	
	-- for disk image selection
	signal diskChgKey : std_logic;
	signal disk_nb : std_logic_vector(7 downto 0);
	-- for debug display selection
	signal dbgChgKey : std_logic;
	signal dbg_nb : std_logic_vector(2 downto 0);
	
	-- for usb keyboard
	signal usb_ctrll : std_logic;
	signal usb_ctrlr : std_logic;
	signal usb_shiftl : std_logic;
	signal usb_shiftr : std_logic;
	signal usb_altl : std_logic;
	signal usb_altr : std_logic;
	signal usb_guil : std_logic;
	signal usb_guir : std_logic;
	signal usb_shift : std_logic;
	signal usb_ctrl: std_logic;
	signal usb_alt: std_logic;
begin

	process (clk)
	begin
		if rising_edge(clk) then
			if diskChgKey = '1' then
				if (key_shiftl or key_shiftr) = '1' then
				  disk_nb <= disk_nb - 1;
				else
				  disk_nb <= disk_nb + 1;					
				end if;
			end if;
			if dbgChgKey = '1' then
				if (key_shiftl or key_shiftr) = '1' then
				  dbg_nb <= dbg_nb - 1;
				else
				  dbg_nb <= dbg_nb + 1;					
				end if;
			end if;
		end if;
	end process;

	disk_num <= disk_nb;
	dbg_num <= dbg_nb;
	
	--
	-- cycle though joystick emulation options on <F11>	
	--
	-- "00" - PORTA = JOYA or JOYKEYS, PORTB = JOYB
	-- "01" - PORTA = JOYA, PORTB = JOYB or JOYKEYS
	-- "10" - PORTA = JOYA, PORTB = JOYKEYS
	-- "11" - PORTA = JOYKEYS, PORTB = JOYA
	
	process (clk) --, reset)
	begin
		if rising_edge(clk) then
			if joySelKey = '1' then
				joySel <= joySel + 1;
			end if;
		end if;
	end process;

	joyA_s <= joyA and not unsigned(joyKeys) when joySel = "00" else
						not unsigned(joyKeys) when joySel = "11" else
						joyA;
	joyB_s <= joyB when joySel = "00" else
						joyB and not unsigned(joyKeys) when joySel = "01" else
						not unsigned(joyKeys) when joySel = "10" else
						joyA;

	matrix: process(clk)
		variable byte_cnt : integer range 0 to 10;
	begin
		--if reset = '1' then
		--	joySelKey <= '0';
		--	joyKeys <= (others => '0');
		if rising_edge(clk) then
			-- reading A, scan pattern on B
			pao(0) <= pai(0) and joyA_s(0) and
				((not backwardsReadingEnabled) or
				((pbi(0) or not key_del) and
				(pbi(1) or not key_return) and
				(pbi(2) or not (key_left or key_right)) and
				(pbi(3) or not key_f7) and
				(pbi(4) or not key_f1) and
				(pbi(5) or not key_f3) and
				(pbi(6) or not key_f5) and
				(pbi(7) or not (key_up or key_down))));
			pao(1) <= pai(1) and joyA_s(1) and
				((not backwardsReadingEnabled) or
				((pbi(0) or not key_3) and
				(pbi(1) or not key_W) and
				(pbi(2) or not key_A) and
				(pbi(3) or not key_4) and
				(pbi(4) or not key_Z) and
				(pbi(5) or not key_S) and
				(pbi(6) or not key_E) and
				(pbi(7) or not (key_left or key_up or key_shiftl))));
			pao(2) <= pai(2) and joyA_s(2) and
				((not backwardsReadingEnabled) or
				((pbi(0) or not key_5) and
				(pbi(1) or not key_R) and
				(pbi(2) or not key_D) and
				(pbi(3) or not key_6) and
				(pbi(4) or not key_C) and
				(pbi(5) or not key_F) and
				(pbi(6) or not key_T) and
				(pbi(7) or not key_X)));
			pao(3) <= pai(3) and joyA_s(3) and
				((not backwardsReadingEnabled) or
				((pbi(0) or not key_7) and
				(pbi(1) or not key_Y) and
				(pbi(2) or not key_G) and
				(pbi(3) or not key_8) and
				(pbi(4) or not key_B) and
				(pbi(5) or not key_H) and
				(pbi(6) or not key_U) and
				(pbi(7) or not key_V)));
			pao(4) <= pai(4) and joyA_s(4) and
				((not backwardsReadingEnabled) or
				((pbi(0) or not key_9) and
				(pbi(1) or not key_I) and
				(pbi(2) or not key_J) and
				(pbi(3) or not key_0) and
				(pbi(4) or not key_M) and
				(pbi(5) or not key_K) and
				(pbi(6) or not key_O) and
				(pbi(7) or not key_N)));
			pao(5) <= pai(5) and
				((not backwardsReadingEnabled) or
				((pbi(0) or not key_plus) and
				(pbi(1) or not key_P) and
				(pbi(2) or not key_L) and
				(pbi(3) or not key_minus) and
				(pbi(4) or not key_dot) and
				(pbi(5) or not key_colon) and
				(pbi(6) or not key_at) and
				(pbi(7) or not key_comma)));
			pao(6) <= pai(6) and
				((not backwardsReadingEnabled) or
				((pbi(0) or not key_pound) and
				(pbi(1) or not key_star) and
				(pbi(2) or not key_semicolon) and
				(pbi(3) or not key_home) and
				(pbi(4) or not key_shiftr) and
				(pbi(5) or not key_equal) and
				(pbi(6) or not key_arrowup) and
				(pbi(7) or not key_slash)));
			pao(7) <= pai(7) and
				((not backwardsReadingEnabled) or
				((pbi(0) or not key_1) and
				(pbi(1) or not key_arrowleft) and
				(pbi(2) or not key_ctrl) and
				(pbi(3) or not key_2) and
				(pbi(4) or not key_space) and
				(pbi(5) or not key_commodore) and
				(pbi(6) or not key_Q) and
				(pbi(7) or not key_runstop)));

			-- reading B, scan pattern on A
			pbo(0) <= pbi(0) and joyB_s(0) and 
				(pai(0) or not key_del) and
				(pai(1) or not key_3) and
				(pai(2) or not key_5) and
				(pai(3) or not key_7) and
				(pai(4) or not key_9) and
				(pai(5) or not key_plus) and
				(pai(6) or not key_pound) and
				(pai(7) or not key_1);
			pbo(1) <= pbi(1) and joyB_s(1) and
				(pai(0) or not key_return) and
				(pai(1) or not key_W) and
				(pai(2) or not key_R) and
				(pai(3) or not key_Y) and
				(pai(4) or not key_I) and
				(pai(5) or not key_P) and
				(pai(6) or not key_star) and
				(pai(7) or not key_arrowleft);
			pbo(2) <= pbi(2) and joyB_s(2) and
				(pai(0) or not (key_left or key_right)) and
				(pai(1) or not key_A) and
				(pai(2) or not key_D) and
				(pai(3) or not key_G) and
				(pai(4) or not key_J) and
				(pai(5) or not key_L) and
				(pai(6) or not key_semicolon) and
				(pai(7) or not key_ctrl);
			pbo(3) <= pbi(3) and joyB_s(3) and
				(pai(0) or not key_F7) and
				(pai(1) or not key_4) and
				(pai(2) or not key_6) and
				(pai(3) or not key_8) and
				(pai(4) or not key_0) and
				(pai(5) or not key_minus) and
				(pai(6) or not key_home) and
				(pai(7) or not key_2);
			pbo(4) <= pbi(4) and joyB_s(4) and
				(pai(0) or not key_F1) and
				(pai(1) or not key_Z) and
				(pai(2) or not key_C) and
				(pai(3) or not key_B) and
				(pai(4) or not key_M) and
				(pai(5) or not key_dot) and
				(pai(6) or not key_shiftr) and
				(pai(7) or not key_space);
			pbo(5) <= pbi(5) and
				(pai(0) or not key_F3) and
				(pai(1) or not key_S) and
				(pai(2) or not key_F) and
				(pai(3) or not key_H) and
				(pai(4) or not key_K) and
				(pai(5) or not key_colon) and
				(pai(6) or not key_equal) and
				(pai(7) or not key_commodore);
			pbo(6) <= pbi(6) and
				(pai(0) or not key_F5) and
				(pai(1) or not key_E) and
				(pai(2) or not key_T) and
				(pai(3) or not key_U) and
				(pai(4) or not key_O) and
				(pai(5) or not key_at) and
				(pai(6) or not key_arrowup) and
				(pai(7) or not key_Q);
			pbo(7) <= pbi(7) and
				(pai(0) or not (key_up or key_down)) and
				(pai(1) or not (key_left or key_up or key_shiftl)) and
				(pai(2) or not key_X) and
				(pai(3) or not key_V) and
				(pai(4) or not key_N) and
				(pai(5) or not key_comma) and
				(pai(6) or not key_slash) and
				(pai(7) or not key_runstop);

			traceKey <= '0';
			trace2Key <= '0';
			videoKey <= '0';
			joySelKey <= '0';
			diskChgKey <= '0';
			dbgChgKey <= '0';
			nmi <= 'Z';
			reset <= 'Z';
			
		if new_usb_report = '1' then
			-- usb keyboard report is 9 bytes
			-- first byte (#0) is max3421e status
			-- then 2 bytes are for modifiers keys
			-- then 6 bytes are normal keys list

			usb_ctrll  <= usb_report(1)(0);
			usb_shiftl <= usb_report(1)(1);
			usb_altl   <= usb_report(1)(2);
			usb_guil   <= usb_report(1)(3);
			usb_ctrlr  <= usb_report(1)(4);
			usb_shiftr <= usb_report(1)(5);
			usb_altr   <= usb_report(1)(6);
			usb_guir   <= usb_report(1)(7);
			usb_shift  <= usb_report(1)(1) or usb_report(1)(5);
			usb_alt    <= usb_report(1)(2) or usb_report(1)(6);
			usb_ctrl   <= usb_report(1)(0) or usb_report(1)(4);
			
			if (usb_ctrl = '1' and usb_alt = '1' and usb_report(3) = X"4C") then
				reset <= '0';		-- three finger salute (ctrl-alt-del)
			end if;
			
			if usb_report(3) = X"01" then
			-- if byte #3 = 0x01 keyboard overflow (too many keys down)
			-- then keep previous keys pattern
				byte_cnt := 10;
			else -- no overflow, allow keys list scanning
				byte_cnt := 3;
								
				key_arrowleft <= '0';
				key_ctrl <= '0'; 
				key_runstop <= '0';
				key_commodore <= '0'; 
				key_shiftl <= '0';
				key_shiftr <= '0';

				key_1 <= '0'; 
				key_2 <= '0'; 
				key_3 <= '0'; 
				key_4 <= '0'; 
				key_5 <= '0'; 
				key_6 <= '0'; 
				key_7 <= '0'; 
				key_8 <= '0';
				key_9 <= '0'; 
				key_0 <= '0'; 
				
				key_A <= '0'; 
				key_B <= '0'; 
				key_C <= '0'; 
				key_D <= '0'; 
				key_E <= '0'; 
				key_F <= '0'; 
				key_G <= '0'; 
				key_H <= '0'; 
				key_I <= '0'; 
				key_J <= '0'; 
				key_K <= '0';
				key_L <= '0'; 
				key_M <= '0'; 
				key_N <= '0'; 
				key_O <= '0'; 
				key_P <= '0'; 
				key_Q <= '0'; 
				key_R <= '0'; 
				key_S <= '0'; 
				key_T <= '0'; 
				key_U <= '0'; 
				key_V <= '0'; 
				key_W <= '0'; 
				key_X <= '0'; 
				key_Y <= '0'; 
				key_Z <= '0'; 

				key_plus <= '0';
				key_minus <= '0';
				key_pound <= '0';
				key_home <= '0'; 
				key_del <= '0'; 

				key_at <= '0'; 
				key_star <= '0'; 
				key_arrowup <= '0';
				
				key_colon <= '0'; 
				key_semicolon <= '0'; 
				key_equal <= '0';
				key_return <= '0'; 
				
				key_F1 <= '0';
				key_F3 <= '0';
				key_F5 <= '0';
				key_F7 <= '0';

				key_comma <= '0'; 
				key_dot <= '0'; 
				key_slash <= '0'; 
				
				key_left <= '0'; 
				key_down <= '0'; 
				key_right <= '0'; 
				key_up <= '0';
				
				key_space <= '0';
			
				joyKeys <= (others => '0');
						
			end if;
		end if;	
		
		-- scan bytes #3 to #9 for normal keys
		if byte_cnt < 10 then	
			-- A-Z
			if ((usb_report(byte_cnt) >= X"04") and (usb_report(byte_cnt) <= X"1D")) then 		
				key_ctrl <= usb_ctrl;
				key_commodore <= usb_alt;
				key_shiftl <= usb_shiftl;
				key_shiftr <= usb_shiftr;
				case usb_report(byte_cnt) is
					when X"04" => 	key_A <= '1'; 
					when X"05" => 	key_B <= '1'; 
					when X"06" => 	key_C <= '1'; 
					when X"07" => 	key_D <= '1'; 
					when X"08" => 	key_E <= '1'; 
					when X"09" => 	key_F <= '1'; 
					when X"0A" => 	key_G <= '1'; 
					when X"0B" => 	key_H <= '1'; 
					when X"0C" => 	key_I <= '1'; 
					when X"0D" => 	key_J <= '1'; 
					when X"0E" => 	key_K <= '1';
					when X"0F" => 	key_L <= '1'; 
					when X"10" => 	key_M <= '1'; 
					when X"11" => 	key_N <= '1'; 
					when X"12" => 	key_O <= '1'; 
					when X"13" => 	key_P <= '1'; 
					when X"14" => 	key_Q <= '1'; 
					when X"15" => 	key_R <= '1'; 
					when X"16" => 	key_S <= '1'; 
					when X"17" => 	key_T <= '1'; 
					when X"18" => 	key_U <= '1'; 
					when X"19" => 	key_V <= '1'; 
					when X"1A" => 	key_W <= '1';
					when X"1B" => 	key_X <= '1'; 
					when X"1C" => 	key_Y <= '1'; 
					when X"1D" => 	key_Z <= '1';
					when others => null;
				end case;
			end if;
		
			-- 0-9
			if (usb_report(byte_cnt) >= X"1E" and usb_report(byte_cnt) <= X"27") then
				key_ctrl <= usb_ctrl;
				key_commodore <= usb_alt;
				-- NON SHIFTED 0-9
				if (usb_shift = '0') then
					case usb_report(byte_cnt) is
						when X"1E" => 	key_1 <= '1';
						when X"1F" => 	key_2 <= '1';
						when X"20" => 	key_3 <= '1';
						when X"21" => 	key_4 <= '1';
						when X"22" => 	key_5 <= '1';
						when X"23" => 	key_6 <= '1';
						when X"24" => 	key_7 <= '1';
						when X"25" => 	key_8 <= '1';
						when X"26" => 	key_9 <= '1';
						when X"27" => 	key_0 <= '1';
						when others => null;
					end case;
				else -- SHIFT 0-9
					key_shiftl <= usb_shiftl;
					key_shiftr <= usb_shiftr;
					case usb_report(byte_cnt) is
						when X"1E" => 	key_1  <= '1';      												-- !  
						when X"1F" => 	key_at <= '1'; key_shiftl <= '0'; key_shiftr <= '0';		-- @  
						when X"20" => 	key_3  <= '1';      												-- #
						when X"21" => 	key_4  <= '1';      												-- $
						when X"22" => 	key_5  <= '1';      												-- %
						when X"23" => 	key_arrowup <= '1'; key_shiftl <='0'; key_shiftr <= '0';-- arrow up	
						when X"24" => 	key_6  <= '1';      												-- &
						when X"25" => 	key_star <= '1'; key_shiftl <='0'; key_shiftr <= '0';	-- *
						when X"26" => 	key_8  <= '1';      												-- (  
						when X"27" => 	key_9  <= '1';      												-- )
						when others => null;
					end case;
				end if;		
			end if;
		
			-- other keys, that don't depend on any modifiers
			case usb_report(byte_cnt) is
				when X"28" => 	key_return 	<= '1';                         -- return 
				when X"58" =>	key_return 	<= '1';                         -- enter on num keypad		
				when X"2C" =>	key_space 	<= '1';                         -- space 
				when X"4F" =>  key_right 	<= '1';                	        -- right cursor
				when X"50" =>  key_right   <= '1'; key_shiftr <= '1';      -- left cursor
				when X"51" =>  key_down 	<= '1';                   		  -- down cursor
				when X"52" =>  key_down 	<= '1'; key_shiftr <= '1';      -- up cursor
				when others => null;
			end case;	
			
			-- UNSHIFTED
			if usb_shift = '0' then	
				case usb_report(byte_cnt) is
					when X"48" => key_runstop <= '1';							  	-- break key -> runstop
					when X"2A" => key_del <= '1';                            -- del
					when x"2D" => key_minus <= '1';									-- -
					when X"2E" => key_equal <= '1';								  	-- =
					when x"2F" => key_colon <= '1';key_shiftr <= '1';			-- [
					when x"30" => key_semicolon <= '1';key_shiftr <= '1';		-- ]
					when X"34" => key_7 <= '1'; key_shiftr <= '1';         	-- ´
					when X"35" => key_arrowleft <= '1'; 						  	-- <- Symbol
					when X"36" => key_comma <= '1';                        	-- ,
					when X"37" => key_dot <= '1';                          	-- .
					when X"38" => key_slash <= '1';   							  	-- /
					when x"33" => key_semicolon <= '1';								-- ;
					when X"49" => key_del <= '1';  key_shiftr <= '1';      	-- insert
					when X"4A" => key_home <= '1';                         	-- home
					when X"4C" => key_del <= '1';								  		-- del
					-- Function keys
					when X"3A" => key_F1 <= '1'; key_shiftr <= '0';				-- F1
					when X"3B" => key_F1 <= '1'; key_shiftr <= '1';				-- F2 (Shift F1)
					when X"3C" => key_F3 <= '1'; key_shiftr <= '0';				-- F3
					when X"3D" => key_F3 <= '1'; key_shiftr <= '1';				-- F4 (Shift F3)
					when X"3E" => key_F5 <= '1'; key_shiftr <= '0';				-- F5
					when X"3F" => key_F5 <= '1'; key_shiftr <= '1';				-- F6 (Shift F5)
					when X"40" => key_F7 <= '1'; key_shiftr <= '0';				-- F7
					when X"41" => key_F7 <= '1'; key_shiftr <= '1';				-- F8 (Shift F7)
					-- Joystick emulation on keypad
					when X"5A" => joyKeys(1) <= '1';   								-- keypad down
					when X"5C" => joyKeys(2) <= '1';   								-- keypad left
					when X"5E" => joyKeys(3) <= '1';   								-- keypad right
					when X"60" => joyKeys(0) <= '1';   								-- keypad up
					when X"62" => joyKeys(4) <= '1';   								-- keypad insert
					-- special keys (technical/debug)	
					when X"42" => traceKey <= '1';   key_shiftr <= usb_shift;-- F9
					when X"43" => dbgChgKey <= '1';  key_shiftr <= usb_shift;-- F10
					when X"9A" => trace2Key <= '1';  key_shiftr <= usb_shift;-- prnt screen/sys req
					when X"4B" => diskChgKey <= '1'; key_shiftr <= usb_shift;-- Page up
					when X"44" => joySelKey <= '1';	key_shiftr <= usb_shift;-- F11
					when X"45" => videoKey <= '1';   key_shiftr <= usb_shift;-- F12
 					when others => null;
				end case;
			else -- SHIFTED
				case usb_report(byte_cnt) is
					when X"2D" =>  key_at <= '1';   key_shiftr <= '0'; key_commodore <= '1'; -- _
					when X"2E" =>  key_plus <= '1'; key_shiftr <= '0';			-- +
					when X"34" =>  key_2 <= '1';    key_shiftr <= '1';     	-- "
					when X"36" =>  key_comma <= '1';key_shiftr <= '1';       -- <
					when X"37" =>  key_dot <= '1';  key_shiftr <= '1';       -- >
					when X"38" =>  key_slash <= '1';key_shiftr <= '1';       -- ?
					when X"4A" =>  key_home <= '1'; key_shiftr <= '1';       -- clear screen (CLR)
					when x"33" =>  key_colon <= '1';key_shiftr <= '0';			-- :
					when X"4C" =>  key_del <= '1';  key_shiftr <= '1';		   -- insert
					when X"2A" =>  key_del <= '1';  key_shiftr <= '1';		   -- insert
					when others => null;
				end case;
			end if;
			byte_cnt := byte_cnt +1;
		end if;			
			
		end if;
	end process;
end architecture;
