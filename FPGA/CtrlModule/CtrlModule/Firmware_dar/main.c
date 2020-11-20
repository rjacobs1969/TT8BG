#include "host.h"

#include "osd.h"
#include "keyboard.h"
#include "menu.h"
#include "ps2.h"
#include "minfat.h"
#include "spi.h"
#include "fileselector.h"

fileTYPE tap_file;
fileTYPE d64_file;

int Load_filetype = 0;

int tap_file_open = 0;
int tap_filesize = 0;
int tap_fileread = 0;
int tap_byte = 0;
int *tap_ptr;

int d64_file_open = 0;
int d64_file_first_cluster;
int d64_current_start_sector = -1;

int OSD_Puts(char *str)
{
	int c;
	while((c=*str++))
		OSD_Putchar(c);
	return(1);
}

/*
void TriggerEffect(int row)
{
	int i,v;
	Menu_Hide();
	for(v=0;v<=16;++v)
	{
		for(i=0;i<4;++i)
			PS2Wait();

		HW_HOST(REG_HOST_SCALERED)=v;
		HW_HOST(REG_HOST_SCALEGREEN)=v;
		HW_HOST(REG_HOST_SCALEBLUE)=v;
	}
	Menu_Show();
}
*/

void Delay(int repeat_delay) // when repeat = 100 delay is around 8ms @81Mhz core clk 
{
	int count, repeat;

	for (repeat = 0; repeat<repeat_delay; repeat++)
	{
		count=16384;
		while(count) // delay some cycles
		{ 
			count--;
		} 
	}
}

void Reset(int row) // row is the line number in menu
{
	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_RESET|HOST_CONTROL_DIVERT_KEYBOARD|HOST_CONTROL_DIVERT_SDCARD; // Reset host core
	Delay(600);
	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_DIVERT_KEYBOARD|HOST_CONTROL_DIVERT_SDCARD; // Release reset
}

void LoadD64File(int row)
{
	Load_filetype = 0;
	FileSelector_Show(row);
}

void LoadTapFile(int row)
{
	Load_filetype = 1;
	FileSelector_Show(row);
}

static struct menu_entry topmenu[]; // Forward declaration.

/*
// RGB scaling submenu
static struct menu_entry rgbmenu[]=
{
	{MENU_ENTRY_SLIDER,"Red",MENU_ACTION(16)},
	{MENU_ENTRY_SLIDER,"Green",MENU_ACTION(16)},
	{MENU_ENTRY_SLIDER,"Blue",MENU_ACTION(16)},
	{MENU_ENTRY_SUBMENU,"Exit",MENU_ACTION(topmenu)},
	{MENU_ENTRY_NULL,0,0}
};
*/

static char *sid_labels[]=
{
	"SID 6581 Mono",
	"SID 6581 Stereo",
	"SID 8580 Mono",
	"SID 8580 Stereo",
	"SID Pseudo Stereo"
};

static char *cia_labels[]=
{
	"CIA 6256",
	"CIA 8521"
};

static char *dbg_labels[]=
{
	"Hex disp. tape count up",
	"Hex disp. tape count down",
	"Hex disp. disk track-sector"
};

// Our toplevel menu
static struct menu_entry topmenu[] =
{
	{MENU_ENTRY_CALLBACK,"Reset C64",MENU_ACTION(&Reset)},
	{MENU_ENTRY_TOGGLE,"C64gs bios",MENU_ACTION(0)},       // 0 is the bit position in menu_toggle_bits
	{MENU_ENTRY_CYCLE,(char *)sid_labels,MENU_ACTION(5)},  // 5 is the number of elements in list
	{MENU_ENTRY_TOGGLE,"Audio filter",MENU_ACTION(1)},     // 1 is the bit position in menu_toggle_bits
	{MENU_ENTRY_CYCLE,(char *)cia_labels,MENU_ACTION(2)},  // 2 is the number of elements in list
	{MENU_ENTRY_CALLBACK,"Load D64 disk \x10",MENU_ACTION(&LoadD64File)},
	{MENU_ENTRY_TOGGLE,"D64 read only",MENU_ACTION(2)},    // 2 is the bit position in menu_toggle_bits
	{MENU_ENTRY_CALLBACK,"Load TAP tape \x10",MENU_ACTION(&LoadTapFile)},
	{MENU_ENTRY_CYCLE,(char *)dbg_labels,MENU_ACTION(3)},  // 3 is the number of elements in list
	{MENU_ENTRY_CALLBACK,"Exit",MENU_ACTION(&Menu_Hide)},
	{MENU_ENTRY_NULL,0,0}
};


// An error message
static struct menu_entry loadfailed[]=
{
	{MENU_ENTRY_SUBMENU,"ROM loading failed",MENU_ACTION(loadfailed)},
	{MENU_ENTRY_SUBMENU,"OK",MENU_ACTION(&topmenu)},
	{MENU_ENTRY_NULL,0,0}
};

static int LoadROM( const char *filename )
{
	int result = 0;

	if (Load_filetype == 1)
	{
		if( FileOpen( &tap_file, filename ))
		{
			result = 1;
			
			HW_HOST( REG_TAP_CONTROL ) = 1; // Reset TAP Loader
			Delay(10);	
			HW_HOST( REG_TAP_CONTROL ) = 0;

			tap_file_open = 1;
			tap_filesize = tap_file.size;
			tap_fileread = 0;
			tap_byte = 512; // trigger read sector on first loop
		}
	}

	if ( Load_filetype == 0)
	{
		if( FileOpen( &d64_file, filename ))
		{
			result = 1;
			d64_file_open = 1;
			d64_current_start_sector = -1;
			d64_file_first_cluster = d64_file.cluster;
			MENU_TOGGLE_VALUES |= 4;  // set disk read only 
		}

	}
	
	if( result ) 
	{
		Menu_Set( topmenu );
		Menu_Hide();
	}
	else
		Menu_Set( loadfailed );
	
	return( result );
}


int main( int argc, char **argv )
{
	int i;
	int dipsw = 0;
	
	tap_file_open = 0;
	d64_file_open = 0;

	HW_HOST( REG_HOST_CONTROL ) = HOST_CONTROL_DIVERT_KEYBOARD | HOST_CONTROL_DIVERT_SDCARD;

	PS2Init();
	EnableInterrupts();

	OSD_Clear();
	
	for( i = 0; i < 4; ++i )
	{
//		PS2Wait();	// Wait for an interrupt - most likely VBlank, but could be PS/2 keyboard
		OSD_Show( 1 );	// Call this over a few frames to let the OSD figure out where to place the window.
	}
	
	OSD_Puts( "Initializing SD card\n" );

	if( !FindDrive() )
		return( 0 );

	FileSelector_SetLoadFunction( LoadROM );
	
	Menu_Set( topmenu );
	Menu_Show();

	while( 1 )
	{
		struct menu_entry *m;
		int visible;
		
		HandlePS2RawCodes();
		
		visible = Menu_Run();

		dipsw = 0;

		if( MENU_TOGGLE_VALUES & 1 ) 
 			dipsw |= 1 ;	           // Add in c64gs bios bit on dipsw[0]

		dipsw |= (MENU_CYCLE_VALUE ( &topmenu[ 2 ] ) & 0x7) << 1; // Take the value of the sid config cycle menu entry (line 3).
		                                                          // and put on dipsw[3:1] (3 bits assuming max value is 4)

		if( MENU_TOGGLE_VALUES & 2 )
			dipsw |= 16;	           // Add in audio filter bit on dipsw[4]

		dipsw |= (MENU_CYCLE_VALUE ( &topmenu[ 4 ] ) & 0x1) << 5; // Take the value of the cia config cycle menu entry (line 5).
		                                                          // and put on dipsw[5] (1 bits assuming max value is 1)

		dipsw |= (MENU_CYCLE_VALUE ( &topmenu[ 8 ] ) & 0x3) << 6; // Take the value of the display config cycle menu entry (line 9).
		                                                          // and put on dipsw[7:6] (2 bits assuming max value is 2)
			
		if( MENU_TOGGLE_VALUES & 4 )
 			dipsw |= 256 ;	           // Add in d64 read only but on dipsw[8]

		HW_HOST( REG_HOST_SW ) = dipsw;	// Send the new values to the hardware.
		
//		HW_HOST(REG_HOST_SCALERED)=MENU_SLIDER_VALUE(&rgbmenu[0]);
//		HW_HOST(REG_HOST_SCALEGREEN)=MENU_SLIDER_VALUE(&rgbmenu[1]);
//		HW_HOST(REG_HOST_SCALEBLUE)=MENU_SLIDER_VALUE(&rgbmenu[2]);

		// If the menu's visible, prevent keystrokes reaching the host core.
		HW_HOST( REG_HOST_CONTROL )=( visible ?
				HOST_CONTROL_DIVERT_KEYBOARD | HOST_CONTROL_DIVERT_SDCARD :
				HOST_CONTROL_DIVERT_SDCARD ); // Maintain control of the SD card so the file selector can work.
				// If the host needs SD card access then we would release the SD
				// card here, and not attempt to load any further files.
	
		if (tap_file_open)
		{
			if (tap_byte == 512)
			{
				if( FileRead( &tap_file, sector_buffer ))
				{
					tap_ptr = ( int * ) &sector_buffer;
					tap_byte = 0;
				}
				else
				{
					HW_HOST( REG_TAP_COUNT_DOWN ) = 0x00dead00;
					HW_HOST( REG_TAP_COUNT_UP ) = 0x00dead00;
					tap_file_open = 0;
				}

				if(tap_file.sector == 0)
				{
					if (sector_buffer[12]== 1)
						HW_HOST( REG_TAP_CONTROL ) = 2; // set tap version to 1 
					else
						HW_HOST( REG_TAP_CONTROL ) = 0; // set tap version to 0
				}
			}
		}

		if (tap_file_open)
		{
			while( ( HW_HOST( REG_TAP_STATUS )& 0x00000001 ) == 1)
			{
				unsigned int data = *tap_ptr++;
				HW_HOST( REG_TAP_DATA ) = data;

				tap_filesize -= 4;
				tap_fileread += 4;

				HW_HOST( REG_TAP_COUNT_DOWN ) = tap_filesize;
				HW_HOST( REG_TAP_COUNT_UP ) = tap_fileread;

				if (tap_filesize <= 0)
				{
					tap_file_open = 0;
					break;
				}
				else
				{
					tap_byte += 4;
					if (tap_byte == 512)
					{
						FileNextSector( &tap_file );
						break;
					}
				}
			}
		}

		if (d64_file_open)
		{
			// Get required track start sector from c1541
			int d64_status;
			int d64_start_sector_req;
			int d64_save_track;

			d64_status = HW_HOST ( REG_D64_STATUS );
			d64_start_sector_req = d64_status & 0x00000FFF;
			d64_save_track = d64_status & 0x00001000;

			// save current track data to d64
			if (d64_save_track)
			{
				HW_HOST( REG_D64_CONTROL ) = 1; // set track_loading
				Delay(100);	

				// Rewind file
				d64_file.cluster = d64_file_first_cluster;
				d64_file.sector = 0;

				// Go to current start sector
				while(d64_file.sector != d64_current_start_sector)
				{
					FileNextSector( &d64_file );
				}

				// Save a full track 11*512 = 22*256 bytes
				// sd sectors are 512 bytes, c1541 sectors are 256 bytes.
				// c1541 max track length is 21 sectors.
				// (actual start track offset is managed at vhdl level)

				while(d64_file.sector != (d64_current_start_sector + 11))
				{
					int i;
					int *p = ( int * ) &sector_buffer;

					for(i = 0; i < 512; i+=4 )
					{
						unsigned int data;
						data = HW_HOST( REG_D64_DATA_IN );
						*p++ = data;
					}


					if( FileWrite( &d64_file, sector_buffer ))					
					{// write error
						d64_file_open = 0;
						break;
					}
					FileNextSector( &d64_file );
				}

				HW_HOST( REG_D64_CONTROL ) = 0; // release track_loading
			} // d64_save_track 


			// Load/Reload track if required sector is not currently loaded
			if (d64_current_start_sector != d64_start_sector_req)
			{
				HW_HOST( REG_D64_CONTROL ) = 1; // set track_loading
				Delay(100);	

				// Rewind file
				d64_file.cluster = d64_file_first_cluster;
				d64_file.sector = 0;

				d64_current_start_sector = d64_start_sector_req;

				// Go to required sector
				while(d64_file.sector != d64_current_start_sector)
				{
					FileNextSector( &d64_file );
				}

				// Load a full track 11*512 = 22*256 bytes
				// sd sectors are 512 bytes, c1541 sectors are 256 bytes.
				// c1541 max track length is 21 sectors.
				// (actual start track offset is managed at vhdl level)

				while(d64_file.sector != (d64_current_start_sector + 11))
				{
					if( FileRead( &d64_file, sector_buffer ))
					{
						int i;
						int *p = ( int * ) &sector_buffer;
				
						for(i = 0; i < 512; i+=4 )
						{
							unsigned int data = *p++;
							HW_HOST( REG_D64_DATA_OUT ) = data;
						}
					}
					else // read error
					{
						d64_file_open = 0;
						break;
					}
					FileNextSector( &d64_file );
				}

				HW_HOST( REG_D64_CONTROL ) = 0; // release track_loading
			} // d64_sector load/reload
		}
	}

	return( 0 );
}
