---------------------------------------------------------------------------------
DE10-Lite is the Top level for the TT8BG by Robin Jacobs (elholandes44@gmail.com)

Current state: 
- a mess

what works: 
- It boots
- external SD2IEC interface
- US layout USB keyboard 

what kind of works:
- scandoubler to convert 15Khz video out into VGA 640x480@60Hz
Only works with NTSC setting
Some artifacts in the midle of the screen
- sound, PWM DAC needs work but it produces sound

what doesn't work:
- OSD can't get it to work, maybe it's because of the scan converter.
- Internal SD with fat32 support
  

-------------------------------------------------------------------------------------------------------
-- DE10 lite Top level for FPGA64_027 by Dar (darfpga@aol.fr) 15-Mai-2019
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
-- Rev 3.1 : 15 Mai 2019 
--   added D64 write support
--
--
-- Rev 3.0 : 08 Mai 2019 
--   added support for FAT32 SD card by using ZPUflex control_module
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
--
--   Fixe SDHC card lba computation in spi_controler.vhd
--
-- Rev 1.0 - 25-May-2017
-- Early release of c64_c1541_sd with WRITE capability for DE10 lite board by Dar (darfpga@aol.fr)
--
-- NO FAT file system, raw sd card access (see README_old on how to put disk image on sd card )
--   
-- See http://darfpga.blogspot.fr for hardware requirements
--
-- Use at your own risk ! Always keep in mind that any sd card data may be lost.
--
-- Tested write operations (from most simple to more complex) :
--   remane file (DOS)  : OPEN15,8,15,"R:NEWNAME=OLDNAME"
--   delete file (DOS)  : OPEN15,8,15,"S:NAME"
--   copy   file (DOS)  : OPEN15,8,15,"C:NEWFILE=OLDFILE"
--   save basic program : SAVE"NAME",8
--
--   beware after DOS operation C64 prompt may return READY immediatly while C1541 activity
--   is not finished. You have to wait for current read sector to be OFF (see below).
--
--
-- DON'T EVER use c1541 NEW (N) command (Format). It is absolutly not supported and may leads
-- to data loss.  
--
-- Board keys :
--
--   key 0 : reset c64, c1541, usb, sd_card
--   key 1 : not used.
--
-- Board switches :
--   
--   switch 0 : up only tested 15KHz   
--   switch 1 : down only tested pal
--
-- Board hex display 
--
--   left most  2digits   : disk number (F8 = next or shift F8 = previous )
--   centre     2digits   : current track number (0x12 = BAM)
--   right most 2digits   : current read sector (OFF = no more drive activity)
--   right most digit dot : sd_card busy
--
-- Board led display :
--
--   left most (9-4) : sd_card machine state, should be 000001 when idle
--   right most(3-0) : usb host/sd_card spi acces arbiter state
--
-- After reset sd_card busy (right most digit dot) should be OFF => reset until you get it.
--
-- Current read sector acts the same as true 1541 drive red led (meaning : under activity)
-- DO NOT change disk number (F8) when current read sector is ON.
--
-- Sd_card busy (Right most digit dot) should only blink briefly. Permanent ON means sd_card is stucked.
--
-- Sd_card and usb host shares the same SPI bus, when sd_card get stucked and don't release the bus 
-- keyboard will be stucked also. Reset will get out of stuck situation but data will be lost.
-- (Using PS/2 keyboard could allow not sharing SPI bus).
--
-------------------------------------------------------------------------------------------------------

For Altera/Quartus and de10 lite, board you should use the following project files (qpf/qsf) that
contains the correct file list and pin assignements :

de10_lite/c64_de10_lite.qpf / qsf

For others software or board the file are listed below :
(do not use extra files from rtl_pace or rtl_fpga64_027 other than the one listed below as they will
conflict with files from rtl_dar)

rtl_dar/max10_pll50_to_33_and_18.vhd
rtl_dar/spi_controller.vhd
rtl_dar/sgtl5000_dac.vhd
rtl_dar/usb_report_pkg.vhd
rtl_dar/usb_host_max3421e.vhd
rtl_dar/decodeur_7_seg.vhd
rtl_dar/fpga64_keyboard_usb_french.vhd
rtl_dar/c64_de10_lite.vhd
rtl_dar/gcr_floppy.vhd
rtl_dar/c1541_sd.vhd
rtl_dar/composite_sync.vhd
rtl_dar/sid6581.vhd
rtl_dar/c1541_logic.vhd

rtl_pace/sid_voice.vhd
rtl_pace/sprom.vhd
rtl_pace/spram.vhd
rtl_pace/m6522.vhd

t65/T65_Pack.vhd
t65/T65_MCode.vhd
t65/T65_ALU.vhd
t65/T65.vhd

% see README_old.txt for explanation on how to get these files

FPGA64_027/sources/rtl/roms/rom_c64_chargen.vhd
FPGA64_027/sources/rtl/roms/rom_c64_kernal.vhd
FPGA64_027/sources/rtl/roms/rom_c64_basic.vhd
FPGA64_027/sources/rtl/video_vicII_656x_e.vhd
FPGA64_027/sources/rtl/io_ps2_keyboard.vhd
FPGA64_027/sources/rtl/gen_rwram.vhd
FPGA64_027/sources/rtl/gen_ram.vhd
FPGA64_027/sources/rtl/fpga64_scandoubler.vhd
FPGA64_027/sources/rtl/fpga64_rgbcolor.vhd
FPGA64_027/sources/rtl/fpga64_hexy_vmode.vhd
FPGA64_027/sources/rtl/fpga64_hexy.vhd
FPGA64_027/sources/rtl/fpga64_cone_scanconverter.vhd
FPGA64_027/sources/rtl/fpga64_bustiming.vhd
FPGA64_027/sources/rtl/cpu65xx_fast.vhd
FPGA64_027/sources/rtl/cpu65xx_e.vhd
FPGA64_027/sources/rtl/cpu_6510.vhd
FPGA64_027/sources/rtl/cia6526.vhd

% see README_old.txt to build these 3 files from FPGA64_027 originals by using fpga64.patch
     
rtl_dar/video_vicII_656x_a.vhd   
rtl_dar/fpga64_sid_iec.vhd
rtl_dar/fpga64_buslogic_roms_mmu.vhd

Top level files is c64_de10_lite.vhd 

At the moment :

 - external 64k sram is needed (but easy to modify for using MAX10 FPGA internal ram instead)
 - usb host for keyboard is used but PS/2 can be reactivated 
 - sgtl5000 for sound is used but PWM can be reactivated

Original english keyboard layout is available only for PS/2
French keyboard layout is available only for USB host.
Layout and interface could be exchanged with little work.

--------------------------------------------------
French keyboard layout uses standard french keys 

-- Normal keys
A-Z        => normal  (graph1/2 via shift/alt left)
0-9 +      => shift
&"'(-)=    => normal
#[@]       => alt gr
,;:!*$<    => normal
?./%£>     => shift

return     => return (entree)
space      => space (espace)

-- Particular keys
run/stop   => tab
commodore  => alt left
ctrl       => ctrl left

crsr up    => up
crsr down  => down
crsr left  => left
crsr right => right

left arrow => ² (carre)
up arrow   => ^ (accent circonflexe)
pi         => ¨ (trema)

home       => debut (home)
clr        => shift debut (shift home)
inst       => inser 
del        => retour arriere (backspace)

graph1(+)  => shift suppr
graph2(+)  => alt left suppr
graph1(-)  => shift fin
graph2(-)  => alt left fin
graph1(£)  => shift page up
graph2(£)  => alt left page up
graph1(@)  => shift page down
graph2(@)  => alt left page down
graph1(*)  => shift *
graph2(*)  => alt left *

blk..yel   => ctrl 1 .. ctrl8
rvs on     => ctrl 9
rvs off    => ctrl 0

-- Function keys    
F1 F3 F5 F7=> F1 F3 F5 F7
F2 F4 F6 F8=> shift F1 F3 F5 F7

-- joystick emulation 
  keypad up/down/left/right
  keypad inser (fire)

  use F11 to cycle between port A/B/keyboard

-- special fonction keys

  F2 F4 F6 F10 => not used
  F8           => sd card disk image + 1
  shift F8     => sd card disk image - 1
  F12	       => toggle pal/ntsc

-------------------------------------------------

Any improvement is welcomed if not exclusively specific to a given board. Feel free to use my own source
code for any non commercial project. See README_old.txt for full intellectual property mentions/links for other
authors.

DAR - make it simple -

												